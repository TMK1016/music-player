import Foundation
import AVFoundation

enum BassCheckError: Error { case failed(String) }
@MainActor enum BassPlanChecks {
    static func require(_ condition: Bool, _ description: String) throws {
        if !condition { throw BassCheckError.failed(description) }
    }
    static func checkMeters() throws {
        for rate in [44100.0, 48000, 96000] {
            let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
            var meter = AudioLevelMeter(rate: rate, channels: 2)
            let peak = try AudioTruePeakMeter(format: format, capacity: 4096)
            for block in 0..<32 {
                buffer.frameLength = 4096
                for c in 0..<2 { for n in 0..<4096 {
                    let position = block*4096+n
                    let fade = min(1, Double(min(position, 32*4096-1-position))/512)
                    buffer.floatChannelData![c][n] = Float(0.1*fade*sin(2 * .pi * 1000 * Double(position)/rate))
                } }
                try meter.consume(buffer); try peak.consume(buffer)
            }
            try peak.finish()
            try require(abs((meter.loudness ?? 0) + 20) < 0.2, "Stereo -20dBFS 1kHz calibration near -20LUFS at \(rate)")
            try require(abs(peak.decibels + 20) < 0.2, "Upsampled peak calibration at \(rate): \(peak.decibels)")
        }
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
        silence.frameLength = 4096
        var meter = AudioLevelMeter(rate: 48000, channels: 1)
        for n in 0..<4096 { silence.floatChannelData![0][n] = 0 }
        try meter.consume(silence)
        try require(meter.loudness == nil, "Silence has no gain target")
        print("PASS: V13 K-weighted stereo loudness, streaming oversampled peak calibration and silence")
    }
    static func writeFixture(_ url: URL, rate: Double, dense: Bool = false, pulse: Bool = false) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
        let settings: [String: Any] = url.pathExtension == "m4a" ? [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: rate, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 192000] : format.settings
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
        let frames = Int(rate*8)
        for start in stride(from: 0, to: frames, by: 4096) {
            let count = min(4096, frames-start); buffer.frameLength = AVAudioFrameCount(count)
            for c in 0..<2 { for n in 0..<count {
                let t = Double(start+n)/rate
                let lowAmount = pulse ? (t >= 3 && t < 3.2 ? 0.9*pow(sin(.pi*(t-3)/0.2), 2) : 0) : (dense ? 0.35 : 0.05)
                let low = lowAmount*sin(2 * .pi * 40*t)
                let mid = (dense ? 0.55 : 0.12)*sin(2 * .pi * 1000*t)
                let high = 0.02*sin(2 * .pi * 4000*t + Double(c)*0.2)
                buffer.floatChannelData![c][n] = Float(low+mid+high)
            } }
            try file.write(from: buffer)
        }
    }
    static func run() async throws -> String {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("music-bass-a-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var rows = ["rate,bass,legacyGain,measuredGain,loudnessError,outputTP,lowLiftDB,midChangeDB,analysisSeconds"]
        for rate in [44100.0, 48000, 96000] {
            let url = root.appendingPathComponent("test-\(Int(rate)).wav")
            try writeFixture(url, rate: rate)
            for bass in [3.0, 6, 9] {
                let request = BassAnalysisRequest(url: url, gains: EQBands.flat, bass: bass, ambience: .off, mix: 0)
                let startTime = Date.timeIntervalSinceReferenceDate
                let result = try await BassAnalysisService.shared.analyze(request)
                let analysisSeconds = Date.timeIntervalSinceReferenceDate - startTime
                let output = try await BassAnalysisService.shared.render(request, bass: bass, gain: result.gainDB)
                let loudnessError = (output.loudness ?? -999) - ((result.dry.loudness ?? 0) + Double(result.referenceGainDB))
                let lowBefore = try NativeEQChecks.renderTone(frequency: 40, gains: EQBands.flat, enabled: true, sampleRate: rate, outputGain: result.referenceGainDB)
                let lowAfter = try NativeEQChecks.renderTone(frequency: 40, gains: EQBands.flat, enabled: true, bass: bass, sampleRate: rate, outputGain: result.gainDB)
                let midBefore = try NativeEQChecks.renderTone(frequency: 1000, gains: EQBands.flat, enabled: true, sampleRate: rate, outputGain: result.referenceGainDB)
                let midAfter = try NativeEQChecks.renderTone(frequency: 1000, gains: EQBands.flat, enabled: true, bass: bass, sampleRate: rate, outputGain: result.gainDB)
                let lift = 20*log10(lowAfter/lowBefore), mid = 20*log10(midAfter/midBefore)
                try require(abs(loudnessError) <= 0.5, "Actual Apple output loudness at \(rate), bass \(bass)")
                try require(output.truePeakDB <= -0.9, "Output peak below engineering ceiling")
                try require(lift > bass*0.5 && mid > -2, "Bass grows without large midrange attenuation")
                let legacy = EQHeadroom.gain(gains: EQBands.flat, bass: bass, sampleRate: rate)
                try require(result.gainDB > legacy + 1, "Content gain recovers avoidable attenuation")
                rows.append("\(rate),\(bass),\(legacy),\(result.gainDB),\(loudnessError),\(output.truePeakDB),\(lift),\(mid),\(analysisSeconds)")
            }
        }
        let compressed = root.appendingPathComponent("compressed.m4a")
        try writeFixture(compressed, rate: 48000)
        let compressedRequest = BassAnalysisRequest(url: compressed, gains: EQBands.flat, bass: 6, ambience: .off, mix: 0)
        let compressedResult = try await BassAnalysisService.shared.analyze(compressedRequest)
        let compressedOutput = try await BassAnalysisService.shared.render(compressedRequest, bass: 6, gain: compressedResult.gainDB)
        try require(abs((compressedOutput.loudness ?? -999) - ((compressedResult.dry.loudness ?? 0) + Double(compressedResult.referenceGainDB))) < 0.5, "AAC offline decoding and loudness matching")
        try require(compressedOutput.truePeakDB <= -0.9, "AAC output peak")
        let dense = root.appendingPathComponent("dense.wav")
        try writeFixture(dense, rate: 48000, dense: true)
        let request = BassAnalysisRequest(url: dense, gains: [12,12,0,0,0,0,0], bass: 9, ambience: .off, mix: 0)
        let limited = try await BassAnalysisService.shared.analyze(request)
        let denseOut = try await BassAnalysisService.shared.render(request, bass: 9, gain: limited.gainDB)
        try require(denseOut.truePeakDB <= -0.9, "Dense bass and EQ overlap remains peak constrained")
        let pulseURL = root.appendingPathComponent("pulse.wav")
        try writeFixture(pulseURL, rate: 48000, pulse: true)
        let pulseRequest = BassAnalysisRequest(url: pulseURL, gains: EQBands.flat, bass: 9, ambience: .off, mix: 0)
        let pulse = try await BassAnalysisService.shared.analyze(pulseRequest)
        let pulseOutput = try await BassAnalysisService.shared.render(pulseRequest, bass: 9, gain: pulse.gainDB)
        try require(pulse.peakLimited, "Sparse strong bass pulse exercises the peak-constrained branch")
        try require(pulseOutput.truePeakDB <= -0.9, "Sparse pulse output remains under the peak ceiling")
        let roomRequest = BassAnalysisRequest(url: dense, gains: [3,2,0,-1,0,1,1], bass: 6, ambience: .room, mix: 15)
        let room = try await BassAnalysisService.shared.analyze(roomRequest)
        let roomOutput = try await BassAnalysisService.shared.render(roomRequest, bass: 6, gain: room.gainDB)
        try require(roomOutput.truePeakDB <= -0.9, "Measured chain includes room reverb and tail")
        if !room.peakLimited {
            try require(abs((roomOutput.loudness ?? -999) - ((room.dry.loudness ?? 0) + Double(room.referenceGainDB))) < 0.5, "Room chain loudness matching")
        }
        let cancelled = Task { try await BassAnalysisService.shared.render(request, bass: 9) }
        cancelled.cancel()
        do { _ = try await cancelled.value; throw BassCheckError.failed("Cancelled analysis returned output") }
        catch is CancellationError { }

        if let path = Bundle.main.object(forInfoDictionaryKey: "ReportPath") as? String {
            try rows.joined(separator: "\n").write(to: URL(fileURLWithPath: path).deletingLastPathComponent().appendingPathComponent("bass-plan-a.csv"), atomically: true, encoding: .utf8)
        }
        return "PASS: V13 Plan A historical reference. Sparse pulse analysis completed: peakLimited=\(pulse.peakLimited), absoluteGain=\(pulse.gainDB)dB, referenceGain=\(pulse.referenceGainDB)dB, wetPeak=\(pulse.wet.truePeakDB)dB. 9 rate/bass combinations, AAC decode, reverb tail, peak stress, cancellation.\n" + rows.joined(separator: "\n")
    }
}
