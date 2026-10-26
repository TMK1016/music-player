import Foundation

/// Log-spaced broad tone controls; not speaker crossovers or exclusive ranges.
enum EQBands {
    static let frequencies: [Double] = [50, 125, 315, 800, 2000, 5000, 12500]
    static let labels = ["50", "125", "315", "800", "2k", "5k", "12.5k"]
    static let bandwidth = 4.0 / 3.0
    static let count = frequencies.count
    static let flat = Array(repeating: 0.0, count: count)
    static let legacyFrequencies: [Double] = [32,64,125,250,500,1000,2000,4000,8000,16000]

    /// Preserve the old control contour by interpolation in log-frequency space.
    /// Wider new filters mean this is an approximation, not an exact DSP match.
    static func migrate(_ values: [Double]) -> [Double] {
        let clean = values.map { $0.isFinite ? min(12, max(-12, $0)) : 0 }
        if clean.count == count { return clean }
        guard clean.count == legacyFrequencies.count else { return flat }
        return frequencies.map { f in
            if f <= legacyFrequencies[0] { return clean[0] }
            if f >= legacyFrequencies.last! { return clean.last! }
            let upper = legacyFrequencies.firstIndex { $0 >= f }!
            let lower = upper - 1
            let t = log(f / legacyFrequencies[lower]) / log(legacyFrequencies[upper] / legacyFrequencies[lower])
            return clean[lower] + t * (clean[upper] - clean[lower])
        }
    }
}
