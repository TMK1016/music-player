import Foundation

/// Frequency-response estimate, not a sample/true-peak limiter or loudness meter.
/// RBJ/W3C peaking EQ (4/3-octave BW) + monotonic low shelf (S = 1).
enum EQHeadroom {
    static let frequencies = EQBands.frequencies
    static let margin = 3.0
    struct Biquad {
        let b0: Double, b1: Double, b2: Double, a0: Double, a1: Double, a2: Double
        func db(at frequency: Double, sampleRate: Double) -> Double {
            let w = 2 * Double.pi * frequency / sampleRate
            let c = cos(w), s = sin(w), c2 = cos(2*w), s2 = sin(2*w)
            let nr = b0 + b1*c + b2*c2, ni = -b1*s - b2*s2
            let dr = a0 + a1*c + a2*c2, di = -a1*s - a2*s2
            return 10 * log10(max(1e-24, (nr*nr + ni*ni) / max(1e-24, dr*dr + di*di)))
        }
    }
    static func safeRate(_ value: Double) -> Double { value.isFinite && value >= 1000 && value <= 768000 ? value : 44100 }
    static func filters(gains: [Double], bass: Double, sampleRate: Double) -> [Biquad] {
        let rate = safeRate(sampleRate)
        var result: [Biquad] = []
        for (index, f) in frequencies.enumerated() where f < rate * 0.45 {
            let gain = index < gains.count && gains[index].isFinite ? min(12, max(-12, gains[index])) : 0
            guard abs(gain) > 1e-8 else { continue }
            let a = pow(10, gain / 40), w = 2 * Double.pi * f / rate
            let alpha = sin(w) * sinh(log(2) / 2 * EQBands.bandwidth * w / sin(w))
            result.append(Biquad(b0: 1+alpha*a, b1: -2*cos(w), b2: 1-alpha*a, a0: 1+alpha/a, a1: -2*cos(w), a2: 1-alpha/a))
        }
        let amount = bass.isFinite ? min(9, max(0, bass)) : 0
        if amount > 0 {
            let a = pow(10, amount / 40), w = 2 * Double.pi * 90 / rate
            let c = cos(w), beta = sin(w) * sqrt(2*a)
            result.append(Biquad(b0: a*((a+1)-(a-1)*c+beta), b1: 2*a*((a-1)-(a+1)*c), b2: a*((a+1)-(a-1)*c-beta), a0: (a+1)+(a-1)*c+beta, a1: -2*((a-1)+(a+1)*c), a2: (a+1)+(a-1)*c-beta))
        }
        return result
    }
    static func response(gains: [Double], bass: Double = 0, sampleRate: Double = 44100, at frequency: Double) -> Double {
        let rate = safeRate(sampleRate)
        guard frequency.isFinite, frequency >= 0, frequency < rate / 2 else { return 0 }
        return filters(gains: gains, bass: bass, sampleRate: rate).reduce(0) { $0 + $1.db(at: frequency, sampleRate: rate) }
    }
    static func peak(gains: [Double], bass: Double = 0, sampleRate: Double = 44100) -> Double {
        let rate = safeRate(sampleRate), stages = filters(gains: gains, bass: bass, sampleRate: sampleRate)
        guard !stages.isEmpty else { return 0 }
        // Log grid, band centers, DC and near-Nyquist; include bass-shelf/EQ overlap.
        let upper = rate * 0.499
        let grid = (0...768).map { 5 * pow(upper / 5, Double($0) / 768) } + frequencies.filter { $0 < upper } + [0, 90]
        return max(0, grid.map { f in stages.reduce(0) { $0 + $1.db(at: f, sampleRate: rate) } }.max() ?? 0)
    }
    static func gain(gains: [Double], bass: Double = 0, sampleRate: Double = 44100, ambience: Ambience = .off, mix: Double = 0) -> Float {
        let reserve = ambience != .off && mix.isFinite && mix > 0 ? 6.0 : 0
        return -Float(min(96, margin + peak(gains: gains, bass: bass, sampleRate: sampleRate) + reserve))
    }
}
