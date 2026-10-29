import Foundation
import Combine
import OSLog

/// Navigation survives page reconstruction; scrolling never publishes PlayerModel.
@MainActor final class HomeLibraryState: ObservableObject {
    @Published var section = "播放清單" { didSet { PlayerDiagnostics.event("LibrarySection:" + section) } }
    @Published var selectedPlaylist: String?
    @Published var selectedArtist: String?
    @Published var allPlaylistsExpanded = false
    @Published var expandedPlaylist: String?
    @Published var expandedArtist: String?
    @Published var monthly = true
    var isShowingDetail: Bool { selectedPlaylist != nil || selectedArtist != nil }
    func returnToRoot() { selectedPlaylist = nil; selectedArtist = nil }
    func selectDetail(_ id: String, artist: Bool) {
        if artist { selectedPlaylist = nil; selectedArtist = id }
        else { selectedArtist = nil; selectedPlaylist = id }
    }
    static let sections = ["播放清單", "歌手列表", "全部歌曲"]
    func handleSwipe(horizontal x: Double, vertical y: Double) {
        if abs(x) >= 60, abs(x) > abs(y) * 1.3, let index = Self.sections.firstIndex(of: section) {
            let next = min(Self.sections.count - 1, max(0, index + (x < 0 ? 1 : -1)))
            if next != index { section = Self.sections[next] }
        } else if section == "播放清單", y >= 50, y > abs(x) * 1.3 {
            allPlaylistsExpanded = true
        }
    }
    var showsRankings: Bool { section == "播放清單" }
    @Published var scrollPositions: [String: String] = [:]
    func recordScrollPosition(_ id: String?, in section: String) {
        // Keep every actual scroll target, including ranking and expanded song rows.
        // Returning a stale header to scrollPosition can fight the user's gesture.
        guard let id, scrollPositions[section] != id else { return }
        scrollPositions[section] = id
    }
}

enum PlayerDiagnostics {
    static let logger = Logger(subsystem: "com.orca.player", category: "performance")
    static let signposter = OSSignposter(subsystem: "com.orca.player", category: .pointsOfInterest)
    static func event(_ event: String) { signposter.emitEvent("Interaction", "\(event, privacy: .public)"); logger.debug("\(event, privacy: .public)") }
}

