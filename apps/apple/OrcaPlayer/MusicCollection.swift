import Foundation

struct SongDetails: Codable, Equatable {
    var title: String?
    var artistID: String?
    var rating: Int?
    var addedAt = Date()
}
struct MusicArtist: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var name: String
    var avatar: Data?
}
struct MusicPlaylist: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var name: String
    var trackIDs: [String] = []
}
struct ListeningEvent: Codable, Equatable {
    var trackID: String
    var date: Date
}
struct MusicCollection: Codable, Equatable {
    var version = 1
    var songs: [String: SongDetails] = [:]
    var artists: [MusicArtist] = []
    var playlists: [MusicPlaylist] = []
    var searches: [String] = []
    var plays: [ListeningEvent] = []
    var playlistOrder: [String] = []
}

extension PlayerModel {
    func details(_ id: String) -> SongDetails { collection.songs[id] ?? SongDetails() }
    func title(_ track: AudioTrack) -> String { collection.songs[track.id]?.title ?? track.title }
    func artist(_ track: AudioTrack) -> String {
        if let id = collection.songs[track.id]?.artistID, let artist = collection.artists.first(where: { $0.id == id }) { return artist.name }
        return track.artist == "本機音檔" ? "未知歌手" : track.artist
    }
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
        var state = collection; state.playlists.removeAll { $0.id == id }; state.playlistOrder.removeAll { $0 == id }; collection = state
    }
    func recordSearch() {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        var state = collection; state.searches.removeAll { $0 == query }; state.searches.insert(query, at: 0); state.searches = Array(state.searches.prefix(10)); collection = state
    }
    func songs(in id: String) -> [AudioTrack] {
        switch id {
        case "all": return tracks
        case "favorites": return tracks.filter { favorites.contains($0.id) }
        case "recent": return tracks.sorted { (collection.songs[$0.id]?.addedAt ?? .distantPast) > (collection.songs[$1.id]?.addedAt ?? .distantPast) }
        case "liked": return tracks.filter { rating($0.id) >= 3 }
        case "unfamiliar": return tracks.filter { (1...3).contains(rating($0.id)) }
        default:
            if id.hasPrefix("stars"), let stars = Int(id.suffix(1)) { return tracks.filter { rating($0.id) == stars } }
            let ids = collection.playlists.first(where: { $0.id == id })?.trackIDs ?? []
            return ids.compactMap { id in tracks.first { $0.id == id } }
        }
    }
    func playCount(_ id: String, monthly: Bool) -> Int {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return collection.plays.filter { $0.trackID == id && (!monthly || calendar.isDate($0.date, equalTo: Date(), toGranularity: .month)) }.count
    }
    func persistCollection() {
        guard !collectionWriteBlocked else { return }
        do {
            try FileManager.default.createDirectory(at: libraryRoot, withIntermediateDirectories: true)
            try JSONEncoder().encode(collection).write(to: libraryRoot.appendingPathComponent("collection-v1.json"), options: .atomic)
        } catch { message = "曲庫分類儲存失敗：" + error.localizedDescription }
    }
    func deleteAudioFile(_ track: AudioTrack) async {
        guard !track.isDemo else { message = "內建試聽音不提供檔案刪除。"; return }
        if selectedID == track.id { audio.pause(); isPlaying = false; loadedID = nil }
        do {
            let imported = try await library.remove(track.id)
            tracks = [.demo] + imported
            var state = collection; state.songs.removeValue(forKey: track.id)
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
    func setPlaybackMode(_ name: String) {
        guard ["順序播放", "單曲重複", "清單循環", "隨機播放"].contains(name) else { return }
        repeatOne = name == "單曲重複"
        repeatAll = name == "清單循環"
        shuffle = name == "隨機播放"
    }
}
