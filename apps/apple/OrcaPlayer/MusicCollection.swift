import Foundation

struct SongDetails: Codable, Equatable, Sendable {
    var title: String?
    var artistID: String?
    var cover: Data?
    var rating: Int?
    var addedAt = Date()
}
struct MusicArtist: Codable, Identifiable, Equatable, Sendable {
    var id = UUID().uuidString
    var name: String
    var avatar: Data?
}
struct MusicPlaylist: Codable, Identifiable, Equatable, Sendable {
    var id = UUID().uuidString
    var name: String
    var trackIDs: [String] = []
}
struct ListeningEvent: Codable, Equatable, Sendable {
    var trackID: String
    var date: Date
}
struct PlaylistAppearance: Codable, Equatable, Sendable {
    var name: String?
    var artwork: Data?
}
struct MusicCollection: Codable, Equatable, Sendable {
    var version = 1
    var songs: [String: SongDetails] = [:]
    var artists: [MusicArtist] = []
    var playlists: [MusicPlaylist] = []
    var searches: [String] = []
    var plays: [ListeningEvent] = []
    var playlistOrder: [String] = []
    var playlistAppearance: [String: PlaylistAppearance]?
    var hiddenPlaylists: Set<String>?
    var artistOrder: [String]?
    var artistSort: String?
    var songOrder: [String]?
    var songSort: String?
}

extension PlayerModel {
    func details(_ id: String) -> SongDetails { collection.songs[id] ?? SongDetails() }
    func title(_ track: AudioTrack) -> String { libraryIndex.titles[track.id] ?? collection.songs[track.id]?.title ?? track.title }
    func artist(_ track: AudioTrack) -> String { libraryIndex.artistNames[track.id] ?? (track.artist == "本機音檔" ? "未知歌手" : track.artist) }
    func rating(_ id: String) -> Int { collection.songs[id]?.rating ?? 0 }
    func setRating(_ id: String, _ value: Int) {
        guard tracks.contains(where: { $0.id == id }), (0...5).contains(value) else { return }
        guard rating(id) != value else { return }
        var info = details(id); info.rating = value == 0 ? nil : value; collection.songs[id] = info
    }
    func editSong(_ track: AudioTrack, title: String, artistName: String) {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 200 else { message = "歌名須為1～200字。"; return }
        let artistName = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard artistName.count <= 100 else { message = "歌手名稱最多100字。"; return }
        var state = collection; var info = details(track.id); info.title = name
        if artistName.isEmpty { info.artistID = nil }
        else if let existing = state.artists.first(where: { $0.name.localizedCaseInsensitiveCompare(artistName) == .orderedSame }) { info.artistID = existing.id }
        else { let artist = MusicArtist(name: artistName); state.artists.append(artist); info.artistID = artist.id }
        state.songs[track.id] = info; collection = state
    }
    func updateArtist(_ id: String, name: String, avatar: Data?) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 100, let index = collection.artists.firstIndex(where: { $0.id == id }) else { return }
        guard !collection.artists.contains(where: { $0.id != id && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) else { message = "已有相同名稱的歌手。"; return }
        var state = collection; state.artists[index].name = name
        if let avatar { guard avatar.count <= 5_000_000 else { message = "頭貼請小於5 MB。"; return }; state.artists[index].avatar = avatar }
        collection = state
    }
    func createPlaylist(_ name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 60 else { message = "清單名稱須為1～60字。"; return }
        guard !collection.playlists.contains(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) else { message = "已有相同名稱的清單。"; return }
        let list = MusicPlaylist(name: name); var state = collection; state.playlists.append(list); state.playlistOrder.append(list.id); collection = state
    }
    func addToPlaylist(_ trackID: String, _ playlistID: String) {
        guard let index = collection.playlists.firstIndex(where: { $0.id == playlistID }), !collection.playlists[index].trackIDs.contains(trackID) else { return }
        collection.playlists[index].trackIDs.append(trackID)
    }
    func removeFromPlaylist(_ trackID: String, _ playlistID: String) {
        guard let index = collection.playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        collection.playlists[index].trackIDs.removeAll { $0 == trackID }
    }
    func deletePlaylist(_ id: String) {
        var state = collection; state.playlists.removeAll { $0.id == id }; state.playlistOrder.removeAll { $0 == id }; state.playlistAppearance?.removeValue(forKey: id); state.hiddenPlaylists?.remove(id); collection = state
    }
    func songs(in id: String) -> [AudioTrack] {
        let index = libraryIndex
        return (index.playlistIDs[id] ?? []).compactMap { index.tracks[$0] }
    }
    func playCount(_ id: String, monthly: Bool) -> Int { (monthly ? libraryIndex.monthlyCounts : libraryIndex.totalCounts)[id, default: 0] }
    func persistCollection() {
        guard !collectionWriteBlocked else { return }
        collectionWriter.enqueue(collection, to: libraryRoot.appendingPathComponent("collection-v1.json")) { [weak self] error in
            Task { @MainActor in self?.message = "曲庫分類儲存失敗：" + error }
        }
    }
    func flushCollection() async { await collectionWriter.flush() }
    var orderedSongs: [AudioTrack] { let index = libraryIndex; return index.orderedIDs.compactMap { index.tracks[$0] } }
    var sortedSongs: [AudioTrack] {
        let index = libraryIndex
        return (index.songOrders[collection.songSort ?? "自訂順序"] ?? index.orderedIDs).compactMap { index.tracks[$0] }
    }
    func moveSong(_ id: String, to target: String) {
        var ids = sortedSongs.map(\.id)
        guard let from = ids.firstIndex(of: id), let to = ids.firstIndex(of: target), from != to else { return }
        ids.remove(at: from); ids.insert(id, at: to); var state = collection; state.songOrder = ids; state.songSort = "自訂順序"; collection = state
    }
    func coverData(_ track: AudioTrack) -> Data? {
        if let cover = collection.songs[track.id]?.cover { return cover }
        let index = libraryIndex
        guard let id = index.artistIDsByName[index.artistNames[track.id] ?? ""] else { return nil }
        return index.artists[id]?.avatar
    }
    func setCover(_ id: String, data: Data?) {
        guard tracks.contains(where: { $0.id == id }), data == nil || data!.count <= 5_000_000 else { return }
        var info = details(id); info.cover = data; collection.songs[id] = info
    }
    func deleteAudioFile(_ track: AudioTrack) async {
        guard !isImporting else { message = "請等本次匯入完成後再刪除音檔。"; return }
        guard !track.isDemo else { message = "內建試聽音不提供檔案刪除。"; return }
        libraryInstallGeneration += 1
        if selectedID == track.id { audio.pause(); isPlaying = false; loadedID = nil }
        do {
            let imported = try await library.remove(track.id)
            tracks = [.demo] + imported
            var state = collection; state.songs.removeValue(forKey: track.id); state.songOrder?.removeAll { $0 == track.id }
            for index in state.playlists.indices { state.playlists[index].trackIDs.removeAll { $0 == track.id } }
            collection = state; favorites.remove(track.id); songBindings.removeValue(forKey: track.id)
            playbackQueue.removeAll { $0 == track.id }
            if selectedID == track.id { choose(.demo, autoplay: false) }
            save()
        } catch { message = "刪除未完成：" + error.localizedDescription }
    }
}

/// Scrub retired settings from both live preferences and the old migration snapshot.
enum PreferencesCleanup {
    static func removingVehicleData(_ data: Data) throws -> Data {
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw LibraryError.corruptManifest }
        object.removeValue(forKey: "vehicle")
        object.removeValue(forKey: "seatDistances")
        return try JSONSerialization.data(withJSONObject: object)
    }
}

enum RatingInteraction {
    static func value(at x: Double, width: Double) -> Int {
        guard x.isFinite, width.isFinite, width > 0 else { return 0 }
        return min(5, max(1, Int(ceil(min(width, max(0, x)) / width * 5))))
    }
}
extension PlayerModel {
    func setPlaybackMode(_ label: String) {
        let name = label == "單曲循環" ? "單曲重複" : label == "歌單循環" ? "清單循環" : label
        guard ["順序播放", "單曲重複", "清單循環", "隨機播放"].contains(name) else { return }
        repeatOne = name == "單曲重複"
        repeatAll = name == "清單循環"
        shuffle = name == "隨機播放"
    }
}

@MainActor extension PlayerModel {
    func cyclePlaybackMode() {
        setPlaybackMode(shuffle ? "歌單循環" : repeatOne ? "隨機播放" : "單曲循環")
    }
}

@MainActor extension PlayerModel {
    static let systemPlaylistIDs = ["favorites", "recent", "stars5", "stars4", "stars3", "stars2", "stars1", "liked", "unfamiliar"]
    func isSystemPlaylist(_ id: String) -> Bool { Self.systemPlaylistIDs.contains(id) }
    func playlistTitle(_ id: String) -> String {
        if let name = collection.playlistAppearance?[id]?.name, !name.isEmpty { return name }
        switch id {
        case "favorites": return "我的最愛"
        case "recent": return "最近新增"
        case "liked": return "喜好歌曲"
        case "unfamiliar": return "陌生歌曲"
        default:
            if id.hasPrefix("stars"), let count = Int(id.suffix(1)), (1...5).contains(count) { return String(repeating: "★", count: count) }
            return collection.playlists.first { $0.id == id }?.name ?? "播放清單"
        }
    }
    var visiblePlaylistIDs: [String] {
        let index = libraryIndex
        let available = Self.systemPlaylistIDs.filter { !(index.playlistIDs[$0] ?? []).isEmpty } + collection.playlists.map(\.id)
        let ordered = collection.playlistOrder.filter { available.contains($0) } + available.filter { !collection.playlistOrder.contains($0) }
        var seen = Set<String>()
        return ordered.filter { !(collection.hiddenPlaylists ?? []).contains($0) && seen.insert($0).inserted }
    }
    func hidePlaylist(_ id: String, hidden: Bool) {
        var state = collection; var values = state.hiddenPlaylists ?? []
        if hidden { values.insert(id) } else { values.remove(id) }
        state.hiddenPlaylists = values; collection = state
    }
    func movePlaylist(_ id: String, to target: String) {
        var ids = visiblePlaylistIDs
        guard let from = ids.firstIndex(of: id), let to = ids.firstIndex(of: target), from != to else { return }
        ids.remove(at: from); ids.insert(id, at: to)
        var state = collection
        state.playlistOrder = ids + state.playlistOrder.filter { !ids.contains($0) }
        collection = state
    }
    func updatePlaylist(_ id: String, name: String, artwork: Data?) -> Bool {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 60, artwork == nil || artwork!.count <= 5_000_000 else { return false }
        let ids = Self.systemPlaylistIDs + collection.playlists.map(\.id)
        guard ids.contains(id), !ids.contains(where: { $0 != id && playlistTitle($0).localizedCaseInsensitiveCompare(title) == .orderedSame }) else { return false }
        var state = collection; var appearances = state.playlistAppearance ?? [:]
        appearances[id] = PlaylistAppearance(name: title, artwork: artwork ?? appearances[id]?.artwork)
        state.playlistAppearance = appearances
        if let i = state.playlists.firstIndex(where: { $0.id == id }) { state.playlists[i].name = title }
        collection = state; return true
    }
    func containsSong(_ trackID: String, inPlaylist id: String) -> Bool { songs(in: id).contains { $0.id == trackID } }
    func togglePlaylistMembership(_ trackID: String, _ id: String) {
        guard tracks.contains(where: { $0.id == trackID }) else { return }
        if id == "favorites", let song = tracks.first(where: { $0.id == trackID }) { toggleFavorite(song); return }
        guard !isSystemPlaylist(id) else { return }
        if containsSong(trackID, inPlaylist: id) { removeFromPlaylist(trackID, id) }
        else { addToPlaylist(trackID, id) }
    }
    func artistKey(_ name: String) -> String { libraryIndex.artistIDsByName[name] ?? "native:" + name }
    func moveArtist(_ id: String, to target: String, in ids: [String]) {
        var order = ids
        guard let from = order.firstIndex(of: id), let to = order.firstIndex(of: target), from != to else { return }
        order.remove(at: from); order.insert(id, at: to)
        var state = collection; state.artistOrder = order; collection = state
    }
    @discardableResult func editableArtist(named name: String) -> MusicArtist {
        if let artist = collection.artists.first(where: { $0.name == name }) { return artist }
        let artist = MusicArtist(name: name)
        var state = collection; state.artists.append(artist)
        for song in tracks where self.artist(song) == name {
            var info = details(song.id); info.artistID = artist.id; state.songs[song.id] = info
        }
        state.artistOrder = (state.artistOrder ?? []).map { $0 == "native:" + name ? artist.id : $0 }
        collection = state; return artist
    }
    var playingListTitle: String {
        guard let id = playbackListID, isSystemPlaylist(id) || collection.playlists.contains(where: { $0.id == id }) else { return playbackContextName }
        return playlistTitle(id)
    }
    var estimatedSleepEnd: Date? {
        if let sleepDeadline { return sleepDeadline }
        guard let count = sleepSongsRemaining else { return nil }
        return estimatedEnd(afterSongs: count)
    }
    func estimatedEnd(afterSongs count: Int) -> Date {
        let count = min(100, max(1, count))
        let remaining = max(0, track.duration - currentTime)
        if repeatOne { return Date().addingTimeInterval(remaining + Double(count - 1) * track.duration) }
        let queue = playbackQueue.compactMap { libraryIndex.tracks[$0] }
        guard !queue.isEmpty else { return Date().addingTimeInterval(remaining + Double(count - 1) * track.duration) }
        if shuffle { return Date().addingTimeInterval(remaining + Double(count - 1) * queue.map(\.duration).reduce(0, +) / Double(queue.count)) }
        let start = queue.firstIndex { $0.id == selectedID } ?? 0
        let seconds = (1..<count).reduce(remaining) { total, offset in total + queue[(start + offset) % queue.count].duration }
        return Date().addingTimeInterval(seconds)
    }
}

@MainActor extension PlayerModel {
    /// Song-to-playlist choices include hidden custom lists; hiding only affects Home.
    var playlistPickerIDs: [String] {
        let choices = collection.playlists.map(\.id) + ["favorites"] + visiblePlaylistIDs
        var seen = Set<String>()
        return choices.filter { seen.insert($0).inserted }
    }
}

@MainActor extension PlayerModel {
    var libraryIndex: LibraryIndex {
        if let cachedLibraryIndex, Date() < cachedLibraryIndex.expiresAt { return cachedLibraryIndex }
        // Synchronous fallback guarantees fresh metadata for edits and injected tests.
        // It is one linear aggregation, not per-row/per-comparison work.
        let index = LibraryIndex.build(tracks: tracks, collection: collection, favorites: favorites)
        cachedLibraryIndex = index
        return index
    }
    func invalidateLibraryIndex() {
        indexRevision += 1; cachedLibraryIndex = nil
    }
    func warmLibraryIndex() async {
        let revision = indexRevision, tracks = tracks, state = collection, favorites = favorites
        let index = await Task.detached(priority: .utility) { LibraryIndex.build(tracks: tracks, collection: state, favorites: favorites) }.value
        guard revision == indexRevision else { return }
        cachedLibraryIndex = index
    }
}
