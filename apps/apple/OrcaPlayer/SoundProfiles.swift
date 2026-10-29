import Foundation

enum Ambience: String, Codable, CaseIterable, Identifiable, Sendable {
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
    /// EQ identity excludes the independent global bass control (legacy stored
    /// profile bass values remain decodable and are never rewritten on selection).
    func matchesEQ(_ other: SoundProfile) -> Bool {
        gains == other.gains && enabled == other.enabled && ambience == other.ambience && mix == other.mix
    }
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

enum EQPreset: String, CaseIterable, Identifiable {
    case flat = "原聲", bass = "低頻", vocal = "人聲", night = "夜間", pop = "流行", rock = "搖滾", jazz = "爵士", classical = "古典", electronic = "電子", acoustic = "木吉他", podcast = "語音", warm = "溫暖", concert = "演唱會"
    var id: String {
        switch self {
        case .flat: "builtin.flat"
        case .bass: "builtin.bass"
        case .vocal: "builtin.vocal"
        case .night: "builtin.night"
        case .pop: "builtin.pop"
        case .rock: "builtin.rock"
        case .jazz: "builtin.jazz"
        case .classical: "builtin.classical"
        case .electronic: "builtin.electronic"
        case .acoustic: "builtin.acoustic"
        case .podcast: "builtin.podcast"
        case .warm: "builtin.warm"
        case .concert: "builtin.concert"
        }
    }
    var gains: [Double] {
        switch self {
        case .flat: EQBands.flat
        case .bass: [3.5, 2, 0, -1, 0, 1, 1]
        case .vocal: [-1, 0, 1, 2, 2.5, 0, -1]
        case .night: [-3, -1, 0, 1, 0, -1, -2]
        case .pop: [1, 1, -1, 0.5, 2, 1, 0]
        case .rock: [2, 1, -1, 0, 2, 1.5, 0]
        case .jazz: [0.5, 1, 0, 0.5, 1, 0, 1]
        case .classical: [0, 0, -0.5, 0, 0.5, 1, 0.5]
        case .electronic: [3, 1, -1, 0, 1, 2, 1]
        case .acoustic: [-1.5, 0, 1, 1.5, 1.5, 0.5, -0.5]
        case .podcast: [-3, -1, 1, 2, 1.5, -1, -2]
        case .warm: [1.5, 2, 0.5, 0, -0.5, -1, -2]
        case .concert: [0.5, 0, -1, 0, 1, 0.5, 0]
        }
    }
}
