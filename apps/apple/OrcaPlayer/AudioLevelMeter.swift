import Accelerate
import AVFoundation
import Foundation

/// Streaming K-weighted, absolute/relative-gated programme loudness.
/// Mono/stereo only. Shorter-than-400ms material uses its available energy.
struct AudioLevelMeter {
    private struct Filter {
        let b0: Double, b1: Double, b2: Double, a1: Double, a2: Double
        private var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        init(b0: Double, b1: Double, b2: Double, a1: Double, a2: Double) {
            self.b0 = b0; self.b1 = b1; self.b2 = b2; self.a1 = a1; self.a2 = a2
        }
        mutating func process(_ input: [Double]) -> [Double] {
            let count = input.count
            guard count > 0 else { return [] }
            let source = [x2, x1] + input
            var output = [Double](repeating: 0, count: count+2)
            output[0] = y2; output[1] = y1
            let coefficients = [b0, b1, b2, a1, a2]
            vDSP_deq22D(source, 1, coefficients, &output, 1, vDSP_Length(count))
            x2 = source[count]; x1 = source[count+1]
            y2 = output[count]; y1 = output[count+1]
            return Array(output.dropFirst(2))
        }
    }
    private var shelf: [Filter], highpass: [Filter]
    private let hop: Int
    private var inHop = 0, frames = 0
    private var hopEnergy = 0.0, totalEnergy = 0.0
    private var recent: [Double] = [], blocks: [Double] = []
    private(set) var samplePeak = 0.0
    init(rate: Double, channels: Int) {
        // BS.1770 K-weighting, bilinear coefficients for the actual sample rate.
        let k = tan(.pi * 1681.974450955533 / rate), q = 0.7071752369554196
        let vh = pow(10, 3.999843853973347 / 20), vb = pow(vh, 0.4996667741545416)
        let a = 1 + k/q + k*k
        let pre = Filter(b0: (vh+vb*k/q+k*k)/a, b1: 2*(k*k-vh)/a,
                         b2: (vh-vb*k/q+k*k)/a, a1: 2*(k*k-1)/a, a2: (1-k/q+k*k)/a)
        let h = tan(.pi * 38.13547087602444 / rate), hq = 0.5003270373238773
        let d = 1+h/hq+h*h
        let post = Filter(b0: 1, b1: -2, b2: 1, a1: 2*(h*h-1)/d, a2: (1-h/hq+h*h)/d)
        shelf = Array(repeating: pre, count: channels); highpass = Array(repeating: post, count: channels)
        hop = max(1, Int((rate * 0.1).rounded()))
    }
    mutating func consume(_ buffer: AVAudioPCMBuffer) throws {
        guard let data = buffer.floatChannelData, Int(buffer.format.channelCount) == shelf.count else { throw PlaybackError.invalidAudio }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return }
        var energy = [Double](repeating: 0, count: count)
        for c in shelf.indices {
            var raw = [Double](repeating: 0, count: count)
            vDSP_vspdp(data[c], 1, &raw, 1, vDSP_Length(count))
            var rawPower = 0.0, rawPeak: Float = 0
            vDSP_svesqD(raw, 1, &rawPower, vDSP_Length(count))
            guard rawPower.isFinite else { throw PlaybackError.invalidAudio }
            vDSP_maxmgv(data[c], 1, &rawPeak, vDSP_Length(count))
            samplePeak = max(samplePeak, Double(rawPeak))
            let pre = shelf[c].process(raw)
            let weighted = highpass[c].process(pre)
            var square = [Double](repeating: 0, count: count)
            vDSP_vsqD(weighted, 1, &square, 1, vDSP_Length(count))
            vDSP_vaddD(energy, 1, square, 1, &energy, 1, vDSP_Length(count))
        }
        var offset = 0
        while offset < count {
            let length = min(count-offset, hop-inHop)
            var sum = 0.0
            energy.withUnsafeBufferPointer { values in
                vDSP_sveD(values.baseAddress! + offset, 1, &sum, vDSP_Length(length))
            }
            guard sum.isFinite else { throw PlaybackError.invalidAudio }
            totalEnergy += sum; hopEnergy += sum; frames += length; inHop += length; offset += length
            if inHop == hop {
                recent.append(hopEnergy); if recent.count > 4 { recent.removeFirst() }
                if recent.count == 4 { blocks.append(recent.reduce(0,+) / Double(hop*4)) }
                inHop = 0; hopEnergy = 0
            }
        }
    }
    var loudness: Double? {
        guard frames > 0 else { return nil }
        let candidates = blocks.isEmpty ? [totalEnergy / Double(frames)] : blocks
        let absolute = pow(10, (-70 + 0.691)/10)
        let gated = candidates.filter { $0.isFinite && $0 > absolute }
        guard !gated.isEmpty else { return nil }
        let relative = gated.reduce(0,+) / Double(gated.count) * 0.1
        let selected = gated.filter { $0 >= relative }
        return -0.691 + 10*log10(selected.reduce(0,+) / Double(selected.count))
    }
}

/// Stateful Apple sample-rate conversion estimates inter-sample peaks.
/// It is not a certified true-peak meter; an extra 0.5dB allowance is applied.
final class AudioTruePeakMeter {
    private let converter: AVAudioConverter?
    private let output: AVAudioPCMBuffer?
    private(set) var peak = 0.0
    init(format: AVAudioFormat, capacity: AVAudioFrameCount) throws {
        let factor = format.sampleRate <= 48000 ? 4.0 : format.sampleRate <= 96000 ? 2.0 : 1.0
        if factor == 1 { converter = nil; output = nil; return }
        guard let up = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: format.sampleRate * factor, channels: format.channelCount, interleaved: false),
              let conversion = AVAudioConverter(from: format, to: up),
              let buffer = AVAudioPCMBuffer(pcmFormat: up, frameCapacity: AVAudioFrameCount(Double(capacity)*factor) + 512) else { throw PlaybackError.invalidAudio }
        conversion.sampleRateConverterQuality = AVAudioQuality.max.rawValue
        converter = conversion; output = buffer
    }
    func consume(_ input: AVAudioPCMBuffer) throws {
        scan(input)
        try convert(input)
    }
    func finish() throws { try convert(nil) }
    private func convert(_ input: AVAudioPCMBuffer?) throws {
        guard let converter, let output else { return }
        var supplied = false
        for _ in 0..<32 {
            var error: NSError?
            let status = converter.convert(to: output, error: &error) { _, state in
                if let input, !supplied { supplied = true; state.pointee = .haveData; return input }
                state.pointee = input == nil ? .endOfStream : .noDataNow
                return nil
            }
            if let error { throw error }
            scan(output)
            switch status {
            case .inputRanDry, .endOfStream: return
            case .haveData: continue
            case .error: throw PlaybackError.invalidAudio
            @unknown default: throw PlaybackError.invalidAudio
            }
        }
        throw PlaybackError.invalidAudio
    }
    private func scan(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData else { return }
        for c in 0..<Int(buffer.format.channelCount) {
            var value: Float = 0
            if buffer.frameLength > 0 { vDSP_maxmgv(data[c], 1, &value, vDSP_Length(buffer.frameLength)) }
            peak = max(peak, Double(value))
        }
    }
    var decibels: Double { 20*log10(max(1e-12, peak)) }
}
