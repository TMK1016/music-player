import AVFoundation
import Foundation

struct BassAnalysisRequest: Hashable, Sendable {
    let url: URL
    let gains: [Double]
    let bass: Double
    let ambience: Ambience
    let mix: Double
}
struct BassMeasurement: Sendable {
    let loudness: Double?
    let truePeakDB: Double
    let samplePeak: Double
}
struct BassAnalysisResult: Sendable {
    let gainDB: Float
    let referenceGainDB: Float
    let dry: BassMeasurement
    let wet: BassMeasurement
    let peakLimited: Bool
}

/// All file decoding, offline graphs, meters and the bounded cache live here,
/// never in the playback render loop or the main actor.
actor BassAnalysisService {
    static let shared = BassAnalysisService()
    static let ceiling = -1.0
    static let peakAllowance = 0.5
    private struct CacheKey: Hashable {
        let request: BassAnalysisRequest
        let size: Int
        let modified: Date
    }
    private var cache: [CacheKey: BassAnalysisResult] = [:]
    private var order: [CacheKey] = []
    func analyze(_ request: BassAnalysisRequest) async throws -> BassAnalysisResult {
        let values = try request.url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let key = CacheKey(request: request, size: values.fileSize ?? 0, modified: values.contentModificationDate ?? .distantPast)
        if let result = cache[key] { return result }
        let dry = try await render(request, bass: 0)
        let wet = try await render(request, bass: request.bass)
        try Task.checkCancellation()
        let file = try AVAudioFile(forReading: request.url)
        let baseline = Double(EQHeadroom.gain(gains: request.gains, bass: 0, sampleRate: file.processingFormat.sampleRate, ambience: request.ambience, mix: request.mix))
        let reference = min(baseline, Self.ceiling - Self.peakAllowance - dry.truePeakDB)
        let result: BassAnalysisResult
        if let ld = dry.loudness, let lw = wet.loudness {
            let match = ld + reference - lw
            let allowed = Self.ceiling - Self.peakAllowance - wet.truePeakDB
            let gain = max(-96, min(0, match, allowed))
            guard gain.isFinite else { throw PlaybackError.invalidAudio }
            result = BassAnalysisResult(gainDB: Float(gain), referenceGainDB: Float(reference), dry: dry, wet: wet, peakLimited: allowed < match)
        } else {
            // Silence is never amplified to chase a loudness target.
            result = BassAnalysisResult(gainDB: EQHeadroom.gain(gains: request.gains, bass: request.bass, sampleRate: file.processingFormat.sampleRate, ambience: request.ambience, mix: request.mix), referenceGainDB: Float(reference), dry: dry, wet: wet, peakLimited: false)
        }
        cache[key] = result; order.append(key)
        if order.count > 32 { cache.removeValue(forKey: order.removeFirst()) }
        return result
    }

    // Schedule synchronously before starting manual rendering; awaiting the
    // async completion variant here would wait for audio that has not rendered.
    private func schedule(_ file: AVAudioFile, on player: AVAudioPlayerNode) {
        player.scheduleFile(file, at: nil, completionHandler: nil)
    }

    /// Renders the actual Apple EQ/bass/reverb chain at unity application volume.
    /// gain is an absolute preamp value; the legacy headroom is not added again.
    func render(_ request: BassAnalysisRequest, bass: Double, gain: Float = 0) async throws -> BassMeasurement {
        try Task.checkCancellation()
        let file = try AVAudioFile(forReading: request.url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = file.processingFormat, rate = format.sampleRate
        guard (1...2).contains(format.channelCount), rate >= 8000, rate <= 192000, file.length > 0 else { throw PlaybackError.invalidAudio }
        let engine = AVAudioEngine(), player = AVAudioPlayerNode()
        let eq = AVAudioUnitEQ(numberOfBands: EQBands.count), low = AVAudioUnitEQ(numberOfBands: 1), reverb = AVAudioUnitReverb()
        engine.attach(player); engine.attach(eq); engine.attach(low); engine.attach(reverb)
        try AudioGraph.connect(engine, player, to: eq, format: format)
        try AudioGraph.connect(engine, eq, to: low, format: format)
        try AudioGraph.connect(engine, low, to: reverb, format: format)
        try AudioGraph.connect(engine, reverb, to: engine.mainMixerNode, format: format)
        EqualizerSettings.apply(to: eq, gains: request.gains, enabled: true, sampleRate: rate)
        switch request.ambience {
        case .off: break
        case .room: reverb.loadFactoryPreset(.smallRoom)
        case .concert: reverb.loadFactoryPreset(.largeHall)
        case .hall: reverb.loadFactoryPreset(.mediumHall)
        case .spacious: reverb.loadFactoryPreset(.largeChamber)
        }
        SoundEffectSettings.apply(equalizer: eq, bassUnit: low, reverb: reverb, gains: request.gains, bass: bass, ambience: request.ambience, mix: request.mix, enabled: true, sampleRate: rate)
        eq.globalGain = gain
        engine.mainMixerNode.outputVolume = 1
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096) else { throw PlaybackError.invalidAudio }
        var meter = AudioLevelMeter(rate: rate, channels: Int(format.channelCount))
        let peaks = try AudioTruePeakMeter(format: format, capacity: 4096)
        schedule(file, on: player)
        defer { player.stop(); engine.stop() }
        try engine.start(); try AudioGraph.play(player)
        let hasTail = request.ambience != .off && request.mix > 0
        let tail = Int64(rate * (hasTail ? 20 : 0.5))
        let limit = file.length + tail
        var retries = 0, iterations = 0
        while engine.manualRenderingSampleTime < limit {
            try Task.checkCancellation()
            let count = AVAudioFrameCount(min(4096, limit - engine.manualRenderingSampleTime))
            let status = try engine.renderOffline(count, to: output)
            if status == .success {
                retries = 0
                try meter.consume(output); try peaks.consume(output)
            } else {
                retries += 1
                guard status != .error, retries < 32 else { throw PlaybackError.invalidAudio }
            }
            iterations += 1
            if iterations % 16 == 0 { await Task.yield() }
        }
        try peaks.finish()
        return BassMeasurement(loudness: meter.loudness, truePeakDB: peaks.decibels, samplePeak: meter.samplePeak)
    }
}
