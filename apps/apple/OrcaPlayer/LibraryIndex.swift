import Foundation
import Combine
import OSLog

struct ArtistGroup: Identifiable, Sendable {
    let id: String
    let name: String
    var songIDs: [String]
    var ratedTotal: Int
    var ratedCount: Int
    var mean: Double { ratedCount == 0 ? 0 : Double(ratedTotal) / Double(ratedCount) }
}
/// Immutable metadata snapshot. No audio/image decoding or disk work.
struct LibraryIndex: Sendable {
    var tracks: [String: AudioTrack] = [:]
    var titles: [String: String] = [:]
    var artistNames: [String: String] = [:]
    var artists: [String: MusicArtist] = [:]
    var artistIDsByName: [String: String] = [:]
    var groups: [String: ArtistGroup] = [:]
    var groupOrders: [String: [String]] = [:]
    var orderedIDs: [String] = []
    var songOrders: [String: [String]] = [:]
    var playlistIDs: [String: [String]] = [:]
    var monthlyCounts: [String: Int] = [:]
    var totalCounts: [String: Int] = [:]
    var monthlyRanking: [String] = []
    var totalRanking: [String] = []
    var builtAt = Date()
    var expiresAt = Date.distantFuture
    static func build(tracks input: [AudioTrack], collection: MusicCollection, favorites: Set<String>, now: Date = Date()) -> LibraryIndex {
        var value = LibraryIndex(); value.builtAt = now
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        let month = calendar.dateInterval(of: .month, for: now)
        value.expiresAt = month?.end ?? now.addingTimeInterval(86400)
        for artist in collection.artists {
            value.artists[artist.id] = artist
            if value.artistIDsByName[artist.name] == nil { value.artistIDsByName[artist.name] = artist.id }
        }
        for track in input {
            value.tracks[track.id] = track
            let info = collection.songs[track.id]
            let name = info?.artistID.flatMap { value.artists[$0]?.name } ?? (track.artist == "本機音檔" ? "未知歌手" : track.artist)
            let key = value.artistIDsByName[name] ?? "native:" + name
            value.artistNames[track.id] = name; value.titles[track.id] = info?.title ?? track.title
            if value.groups[key] == nil { value.groups[key] = ArtistGroup(id: key, name: name, songIDs: [], ratedTotal: 0, ratedCount: 0) }
            value.groups[key]!.songIDs.append(track.id)
            let rating = info?.rating ?? 0
            if rating > 0 { value.groups[key]!.ratedTotal += rating; value.groups[key]!.ratedCount += 1 }
            if favorites.contains(track.id) { value.playlistIDs["favorites", default: []].append(track.id) }
            if rating >= 3 { value.playlistIDs["liked", default: []].append(track.id) }
            if (1...3).contains(rating) { value.playlistIDs["unfamiliar", default: []].append(track.id) }
            if rating > 0 { value.playlistIDs["stars\(rating)", default: []].append(track.id) }
            if !track.isDemo, let added = info?.addedAt {
                let expiry = added.addingTimeInterval(7 * 86400)
                if expiry >= now { value.playlistIDs["recent", default: []].append(track.id); value.expiresAt = min(value.expiresAt, expiry.addingTimeInterval(0.01)) }
            }
        }
        value.playlistIDs["recent"]?.sort { (collection.songs[$0]?.addedAt ?? .distantPast) > (collection.songs[$1]?.addedAt ?? .distantPast) }
        var seen = Set<String>()
        value.orderedIDs = ((collection.songOrder ?? []) + input.map(\.id)).filter { value.tracks[$0] != nil && seen.insert($0).inserted }
        value.playlistIDs["all"] = value.orderedIDs
        value.songOrders["自訂順序"] = value.orderedIDs
        switch collection.songSort {
        case "歌名": value.songOrders["歌名"] = value.orderedIDs.sorted { value.titles[$0, default: ""].localizedStandardCompare(value.titles[$1, default: ""]) == .orderedAscending }
        case "歌手": value.songOrders["歌手"] = value.orderedIDs.sorted { value.artistNames[$0, default: ""].localizedStandardCompare(value.artistNames[$1, default: ""]) == .orderedAscending }
        case "最近新增": value.songOrders["最近新增"] = value.orderedIDs.sorted { (collection.songs[$0]?.addedAt ?? .distantPast) > (collection.songs[$1]?.addedAt ?? .distantPast) }
        default: break
        }
        for playlist in collection.playlists { value.playlistIDs[playlist.id] = playlist.trackIDs.filter { value.tracks[$0] != nil } }
        for event in collection.plays {
            value.totalCounts[event.trackID, default: 0] += 1
            if let month, event.date >= month.start && event.date < month.end { value.monthlyCounts[event.trackID, default: 0] += 1 }
        }
        let locale = Locale(identifier: "zh_Hant_TW@collation=stroke")
        let names = value.groups.values.sorted { $0.name.compare($1.name, options: [.numeric], locale: locale) == .orderedAscending }
        let order = Dictionary((collection.artistOrder ?? []).enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { first, _ in first })
        value.groupOrders["名字筆畫"] = names.map(\.id)
        value.groupOrders["歌曲數目"] = names.sorted { $0.songIDs.count > $1.songIDs.count }.map(\.id)
        value.groupOrders["喜好高低"] = names.sorted { $0.mean > $1.mean }.map(\.id)
        value.groupOrders["自訂順序"] = names.sorted { order[$0.id, default: Int.max] < order[$1.id, default: Int.max] }.map(\.id)
        func ranking(_ counts: [String: Int]) -> [String] {
            input.filter { counts[$0.id, default: 0] > 0 }.sorted {
                let a = counts[$0.id, default: 0], b = counts[$1.id, default: 0]
                return a == b ? value.titles[$0.id, default: ""] < value.titles[$1.id, default: ""] : a > b
            }.map(\.id)
        }
        value.monthlyRanking = ranking(value.monthlyCounts); value.totalRanking = ranking(value.totalCounts)
        return value
    }
}

/// Navigation survives page reconstruction; scrolling never publishes PlayerModel.
@MainActor final class HomeLibraryState: ObservableObject {
    @Published var section = "播放清單" { didSet { PlayerDiagnostics.event("LibrarySection:" + section) } }
    @Published var expandedPlaylist: String?
    @Published var expandedArtist: String?
    @Published var monthly = true
    @Published var limit = 50
    @Published var scrollPositions: [String: String] = [:]
}

enum PlayerDiagnostics {
    static let logger = Logger(subsystem: "com.orca.player", category: "performance")
    static let signposter = OSSignposter(subsystem: "com.orca.player", category: .pointsOfInterest)
    static func event(_ event: String) { signposter.emitEvent("Interaction", "\(event, privacy: .public)"); logger.debug("\(event, privacy: .public)") }
}
