import Foundation
import Combine
import OSLog

/// Navigation survives page reconstruction; scrolling never publishes PlayerModel.
@MainActor final class HomeLibraryState: ObservableObject {
    @Published var section = "播放清單" { didSet { PlayerDiagnostics.event("LibrarySection:" + section) } }
    @Published var expandedPlaylist: String?
    @Published var expandedArtist: String?
    @Published var monthly = true
    var showsRankings: Bool { section == "播放清單" }
    @Published var scrollPositions: [String: String] = [:]
}

enum PlayerDiagnostics {
    static let logger = Logger(subsystem: "com.orca.player", category: "performance")
    static let signposter = OSSignposter(subsystem: "com.orca.player", category: .pointsOfInterest)
    static func event(_ event: String) { signposter.emitEvent("Interaction", "\(event, privacy: .public)"); logger.debug("\(event, privacy: .public)") }
}

