import Foundation
import AVFoundation

@MainActor enum NativeEQChecks {
    static func run() throws -> String {

        let flat = try renderTone(frequency: 800, gains: Array(repeating: 0, count: EQBands.count), enabled: true)
        var boost = Array(repeating: 0.0, count: EQBands.count); boost[3] = 6
        let filtered = try renderTone(frequency: 800, gains: boost, enabled: true)
        let bypass = try renderTone(frequency: 800, gains: boost, enabled: false)
        let difference = 20 * log10(filtered / bypass)
        precondition(abs(difference - 6) < 0.6, "800Hz band must boost 800Hz by ~6dB relative to bypass")
        let headroomDifference = 20 * log10(bypass / flat)
        precondition(abs(headroomDifference + 6) < 0.4, "Headroom is retained during bypass")
        let lowRate = AVAudioUnitEQ(numberOfBands: EQBands.count)
        EqualizerSettings.apply(to: lowRate, gains: boost, enabled: true, sampleRate: 16_000)
        precondition(lowRate.bands[6].bypass && !lowRate.bands[5].bypass, "Above-Nyquist bands are bypassed")
        let bassDry = try renderTone(frequency: 32, gains: Array(repeating: 0, count: EQBands.count), enabled: false, bass: 6)
        let bassWet = try renderTone(frequency: 32, gains: Array(repeating: 0, count: EQBands.count), enabled: true, bass: 6)
        let bassDelta = 20 * log10(bassWet / bassDry)
        precondition(bassDelta > 5 && bassDelta < 7, "Low shelf boosts 32Hz by approximately 6dB")
        let trebleDry = try renderTone(frequency: 4000, gains: Array(repeating: 0, count: EQBands.count), enabled: false, bass: 6)
        let trebleWet = try renderTone(frequency: 4000, gains: Array(repeating: 0, count: EQBands.count), enabled: true, bass: 6)
        precondition(abs(20 * log10(trebleWet / trebleDry)) < 0.3, "Bass shelf does not boost treble")
        let tail = try renderTone(frequency: 800, gains: Array(repeating: 0, count: EQBands.count), enabled: true, ambience: .concert, burst: true)
        let dryTail = try renderTone(frequency: 800, gains: Array(repeating: 0, count: EQBands.count), enabled: false, ambience: .concert, burst: true)
        precondition(tail > 0.000001 && dryTail < 0.00000001, "Reverb produces a real decay tail; master bypass removes it")
        let shapes: [(String, [Double], Double)] = [
            ("all+3", Array(repeating: 3, count: EQBands.count), 0),
            ("all+12", Array(repeating: 12, count: EQBands.count), 9),
            ("alternating", [12,-12,12,-12,12,-12,12], 6),
            ("bass", [3.5,2,0,-1,0,1,1], 3),
            ("cuts", Array(repeating: -6, count: EQBands.count), 0)
        ]
        var maxError = 0.0, maxUnderestimate = 0.0, rows = ["shape,sampleRate,frequency,measuredDB,estimatedDB,compensatedDB"]
        for rate in [16000.0, 44100.0, 48000.0] {
            for (name, gains, bass) in shapes {
                for frequency in [32.0,50,90,125,315,800,2000,5000,12500] where frequency < rate * 0.45 {
                    let dry = try renderTone(frequency: frequency, gains: gains, enabled: false, bass: bass, sampleRate: rate)
                    let wet = try renderTone(frequency: frequency, gains: gains, enabled: true, bass: bass, sampleRate: rate)
                    let measured = 20 * log10(wet/dry)
                    let estimated = EQHeadroom.response(gains: gains, bass: bass, sampleRate: rate, at: frequency)
                    maxError = max(maxError, abs(measured-estimated))
                    maxUnderestimate = max(maxUnderestimate, measured-estimated)
                    let compensated = measured + Double(EQHeadroom.gain(gains: gains, bass: bass, sampleRate: rate))
                    rows.append("\(name),\(rate),\(frequency),\(measured),\(estimated),\(compensated)")
                    precondition(compensated < 0.1, "Tested steady-state tone must retain headroom")
                }
            }
        }
        if let path = Bundle.main.object(forInfoDictionaryKey: "ReportPath") as? String {
            try rows.joined(separator: "\n").write(toFile: URL(fileURLWithPath: path).deletingLastPathComponent().appendingPathComponent("response-comparison.csv").path, atomically: true, encoding: .utf8)
        }
        precondition(maxUnderestimate < EQHeadroom.margin, "Apple/model response mismatch must remain within the margin in tested cases")
        return String(format: "PASS: native EQ offline PCM rendering; 800Hz boost = %.2f dB; bypass compensation delta = %.2f dB", difference, headroomDifference) + String(format: "; bass shelf at 32Hz = %.2f dB; reverb tail RMS = %.8f; bypass tail RMS = %.8f", bassDelta, tail, dryTail) + String(format: "; combined-response probes = %d; max model error = %.3f dB; max underestimate = %.3f dB", rows.count - 1, maxError, maxUnderestimate)
    }

    @MainActor static func renderTone(frequency: Double, gains: [Double], enabled: Bool, bass: Double = 0, ambience: Ambience = .off, burst: Bool = false, sampleRate: Double = 44100) throws -> Double {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let equalizer = AVAudioUnitEQ(numberOfBands: EQBands.count)
        let bassUnit = AVAudioUnitEQ(numberOfBands: 1)
        let reverb = AVAudioUnitReverb()
        reverb.loadFactoryPreset(.largeHall)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let frames = AVAudioFrameCount(sampleRate)
        let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        input.frameLength = frames
        for channel in 0..<2 {
            for i in 0..<Int(frames) { input.floatChannelData![channel][i] = Float((burst && i > 2205 ? 0 : 0.08) * sin(2 * .pi * frequency * Double(i) / sampleRate)) }
        }
        engine.attach(player); engine.attach(equalizer); engine.attach(bassUnit); engine.attach(reverb)
        try AudioGraph.connect(engine, player, to: equalizer, format: format)
        try AudioGraph.connect(engine, equalizer, to: bassUnit, format: format)
        try AudioGraph.connect(engine, bassUnit, to: reverb, format: format)
        try AudioGraph.connect(engine, reverb, to: engine.mainMixerNode, format: format)
        EqualizerSettings.apply(to: equalizer, gains: gains, enabled: enabled, sampleRate: sampleRate)
        SoundEffectSettings.apply(equalizer: equalizer, bassUnit: bassUnit, reverb: reverb, gains: gains, bass: bass, ambience: ambience, mix: 25, enabled: enabled, sampleRate: sampleRate)
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 1024)
        try engine.start()
        defer { player.stop(); engine.stop() }
        player.scheduleBuffer(input)
        try AudioGraph.play(player)
        let output = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 1024)!
        var squareSum = 0.0, count = 0, attempts = 0
        while engine.manualRenderingSampleTime < Int64(frames) && attempts < 1000 {
            attempts += 1
            let remaining = Int64(frames) - engine.manualRenderingSampleTime
            let status = try engine.renderOffline(AVAudioFrameCount(min(1024, remaining)), to: output)
            if status == .success && engine.manualRenderingSampleTime > Int64(sampleRate * 0.25) {
                for i in 0..<Int(output.frameLength) {
                    let value = Double(output.floatChannelData![0][i])
                    precondition(value.isFinite, "Finite EQ output")
                    squareSum += value * value; count += 1
                }
            }
        }
        precondition(count > Int(sampleRate * 0.5) && (burst || squareSum > 0), "Offline engine must render nonzero PCM")
        return sqrt(squareSum / Double(count))
    }
}
