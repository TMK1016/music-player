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
enum SpeakerType: String, Codable, CaseIterable, Identifiable {
    case component2 = "二音路分音", component3 = "三音路分音", coaxial = "同軸", fullRange = "全音域", none = "未安裝"
    var id: String { rawValue }
    var drivers: [String] {
        switch self {
        case .component2: ["高音", "中低音"]
        case .component3: ["高音", "中音", "低音"]
        case .coaxial: ["同軸總成"]
        case .fullRange: ["全音域"]
        case .none: []
        }
    }
}
struct VehicleSettings: Codable {
    var name = "Ford Fiesta B299-7v · 2017"
    var connection = "藍牙"
    var front: SpeakerType = .component2
    var rear: SpeakerType = .coaxial
    var seat = "駕駛座"
    var subwoofer = false
    var speakers: [String] {
        ["前左", "前右"].flatMap { side in front.drivers.map { side + " · " + $0 } } +
        ["後左", "後右"].flatMap { side in rear.drivers.map { side + " · " + $0 } } + (subwoofer ? ["超低音"] : [])
    }
}

struct ModeOption: Identifiable {
    let id: String
    let name: String
    let isCustom: Bool
}
