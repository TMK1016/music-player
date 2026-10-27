import Foundation

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
    var metadata: [String: TrackMetadata] = [:]
    var artists: [String: MusicArtist] = [:]
    var artistIDsByName: [String: String] = [:]
    var groups: [String: ArtistGroup] = [:]
    var groupOrders: [String: [String]] = [:]
    var orderedIDs: [String] = []
    var sortedSongIDs: [String] = []
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
            let metadata = TrackMetadata.resolve(track, details: info,
                artistByID: { value.artists[$0] },
                artistByName: { value.artistIDsByName[$0].flatMap { value.artists[$0] } })
            let name = metadata.artist
            let key = value.artistIDsByName[name] ?? "native:" + name
            value.metadata[track.id] = metadata
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
        let mode = collection.effectiveSongSort
        func titleBefore(_ a: String, _ b: String) -> Bool {
            let result = (value.metadata[a]?.title ?? "").compare((value.metadata[b]?.title ?? ""), options: [.numeric], locale: Locale(identifier: "zh_Hant_TW@collation=stroke"))
            return result == .orderedSame ? a < b : result == .orderedAscending
        }
        let ascending = value.orderedIDs.sorted { a, b in
            if mode == "自訂順序" { return false }
            if mode == "喜好程度" {
                let x = collection.songs[a]?.rating ?? 0, y = collection.songs[b]?.rating ?? 0
                if x != y { return x < y }
            } else if mode == "最近新增" {
                let x = collection.songs[a]?.addedAt ?? .distantPast, y = collection.songs[b]?.addedAt ?? .distantPast
                if x != y { return x < y }
            } else if mode == "歌手" {
                let x = (value.metadata[a]?.artist ?? ""), y = (value.metadata[b]?.artist ?? "")
                let result = x.localizedStandardCompare(y)
                if result != .orderedSame { return result == .orderedAscending }
            }
            return titleBefore(a, b)
        }
        value.sortedSongIDs = collection.isSongSortAscending ? ascending : ascending.reversed()
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
                return a == b ? (value.metadata[$0.id]?.title ?? "") < (value.metadata[$1.id]?.title ?? "") : a > b
            }.map(\.id)
        }
        value.monthlyRanking = ranking(value.monthlyCounts); value.totalRanking = ranking(value.totalCounts)
        return value
    }
}

/// Persisted labels remain compatible with collection-v1; only these choices appear in V8.
enum SongSortMode: String, CaseIterable {
    case stroke = "筆畫數", rating = "喜好程度", recent = "最近新增"
    var defaultAscending: Bool { self == .stroke }
}

extension MusicCollection {
    var effectiveSongSort: String {
        switch songSort {
        case "歌名": return SongSortMode.stroke.rawValue
        case "自訂順序", "歌手": return songSort!
        case let value? where SongSortMode(rawValue: value) != nil: return value
        default: return (songOrder ?? []).isEmpty ? SongSortMode.stroke.rawValue : "自訂順序"
        }
    }
    var isSongSortAscending: Bool {
        songSortAscending ?? (SongSortMode(rawValue: effectiveSongSort)?.defaultAscending ?? true)
    }
    mutating func selectSongSort(_ mode: SongSortMode) {
        let ascending = effectiveSongSort == mode.rawValue ? !isSongSortAscending : mode.defaultAscending
        songSort = mode.rawValue; songSortAscending = ascending
    }
}
