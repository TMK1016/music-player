import Foundation

enum Ambience: String, Codable, CaseIterable, Identifiable {
    case off = "關閉", room = "錄音室", concert = "演唱會", hall = "音樂廳", spacious = "寬廣空間"
    var id: String { rawValue }
}
struct SoundProfile: Codable, Equatable {
    var gains: [Double]
    var enabled: Bool
    var bass: Double
    var ambience: Ambience
    var mix: Double
    static let flat = SoundProfile(gains: EQBands.flat, enabled: true, bass: 0, ambience: .off, mix: 15)
    var sanitized: SoundProfile {
        var p = self
        p.gains = EQBands.migrate(gains)
        p.bass = bass.isFinite ? min(9, max(0, bass)) : 0
        p.mix = mix.isFinite ? min(35, max(0, mix)) : 15
        return p
    }
}
struct CustomPreset: Codable, Identifiable {
    var id: String
    var name: String
    var sound: SoundProfile
}

struct ModeOption: Identifiable {
    let id: String
    let name: String
    let isCustom: Bool
}
