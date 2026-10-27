import Foundation
import Combine

@MainActor enum LibraryIndexChecks {
    static func checkV8Ordering() throws {
        let titles = ["三", "二", "一", "一", "", "A10", "A2"]
        let tracks = titles.enumerated().map { AudioTrack(id: "id.\($0.offset)", title: $0.element, artist: "Artist", collection: "Synthetic", duration: 18, artwork: 0, filename: "fixture.wav", sampleRate: 44100, channels: 2, fileType: "WAV") }
        var state = MusicCollection()
        state.songOrder = tracks.reversed().map(\.id)
        for (i, track) in tracks.enumerated() {
            var info = SongDetails(); info.rating = i == 0 ? nil : min(i, 5)
            info.addedAt = Date(timeIntervalSince1970: Double(i / 2))
            state.songs[track.id] = info
        }
        let originalOrder = state.songOrder
        func ids(_ state: MusicCollection) -> [String] {
            let index = LibraryIndex.build(tracks: tracks, collection: state, favorites: [])
            return index.sortedSongIDs
        }
        state.selectSongSort(.stroke)
        let stroke = ids(state)
        precondition(stroke.first == "id.4" && stroke.firstIndex(of: "id.6")! < stroke.firstIndex(of: "id.5")!, "Empty first and numeric mixed titles")
        precondition(stroke.firstIndex(of: "id.2")! < stroke.firstIndex(of: "id.1")! && stroke.firstIndex(of: "id.1")! < stroke.firstIndex(of: "id.0")!, "Traditional stroke order: 一 二 三")
        precondition(stroke.firstIndex(of: "id.2")! < stroke.firstIndex(of: "id.3")!, "Identical titles use stable ID tie-break")
        state.selectSongSort(.stroke); precondition(ids(state) == stroke.reversed(), "Second selection reverses entire order")
        state.selectSongSort(.rating); precondition(ids(state).last == "id.0", "Rating defaults highest first, unrated zero last")
        let high = ids(state)
        state.selectSongSort(.rating); precondition(ids(state).first == "id.0" && ids(state) == high.reversed(), "Ascending starts unrated and reverses ties consistently")
        state.selectSongSort(.recent); precondition(ids(state).first == "id.6", "Recent defaults newest first")
        let recent = ids(state)
        state.selectSongSort(.recent); precondition(ids(state) == recent.reversed(), "Recent reverses")
        state.selectSongSort(.stroke); precondition(ids(state) == stroke, "Switching resets default direction")
        precondition(state.songOrder == originalOrder, "Sorting never overwrites legacy custom order")
        let restored = try JSONDecoder().decode(MusicCollection.self, from: JSONEncoder().encode(state))
        precondition(restored == state && ids(restored) == stroke, "New fields round-trip without data loss")
        var legacyObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as! [String: Any]
        legacyObject.removeValue(forKey: "songSortAscending"); legacyObject["songSort"] = "歌名"
        let legacy = try JSONDecoder().decode(MusicCollection.self, from: JSONSerialization.data(withJSONObject: legacyObject))
        precondition(legacy.effectiveSongSort == "筆畫數" && ids(legacy) == stroke && legacy.songOrder == originalOrder, "Old title mode migrates without losing order/data")
        let fresh = MusicCollection()
        precondition(fresh.effectiveSongSort == "筆畫數" && fresh.isSongSortAscending, "New library defaults to stroke ascending")
        let navigation = HomeLibraryState()
        precondition(navigation.showsRankings, "Playlists shows rankings")
        for section in ["歌手列表", "全部歌曲"] { navigation.section = section; precondition(!navigation.showsRankings) }
        print("PASS: V8 stroke/rating/date, reversal/reset, stable ties, legacy migration, persistence and ranking scope")
    }
    static func run(work: URL, fixture: URL) async throws {
        try checkV8Ordering()
        let root = work.appendingPathComponent("indexed-library")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: fixture, to: root.appendingPathComponent("fixture.wav"))
        let audio = FakeAudioPlayer()
        var publications: [NowPlayingSnapshot] = []
        let publisher = NowPlayingCoordinator { publications.append($0) }
        let model = PlayerModel(audio: audio, libraryRoot: root, demoURL: fixture, nowPlaying: publisher)
        model.collectionWriteBlocked = true
        var timing: [[String: Double]] = []
        for count in [1230, 5000, 10000] {
            var state = MusicCollection()
            state.artists = (0..<200).map { MusicArtist(id: "artist.\($0)", name: "Singer \($0)") }
            model.tracks = (0..<count).map { AudioTrack(id: "song.\($0)", title: "Title \($0)", artist: "本機音檔", collection: "Synthetic", duration: 18, artwork: 0, filename: "fixture.wav", sampleRate: 44100, channels: 2, fileType: "WAV") }
            for i in 0..<count { var details = SongDetails(); details.artistID = state.artists[i % 200].id; details.rating = i % 6 == 0 ? nil : i % 6; state.songs["song.\(i)"] = details }
            state.plays = (0..<(count * 4)).map { ListeningEvent(trackID: "song.\($0 % count)", date: Date()) }
            model.collection = state
            let start = ProcessInfo.processInfo.systemUptime
            let index = model.libraryIndex
            let buildMS = (ProcessInfo.processInfo.systemUptime - start) * 1000
            precondition(index.tracks.count == count && index.monthlyRanking.count == count && index.totalCounts["song.0"] == 4, "Whole library counts remain complete")
            precondition(index.groups.count == 200 && index.groups["artist.0"]?.songIDs.count == (count + 199) / 200, "Artist grouping matches exact fixture")
            let hotStart = ProcessInfo.processInfo.systemUptime
            for _ in 0..<100 { precondition(model.libraryIndex.groupOrders["歌曲數目"]?.count == 200); precondition(model.playCount("song.0", monthly: true) == 4) }
            let hotMS = (ProcessInfo.processInfo.systemUptime - hotStart) * 1000
            timing.append(["tracks": Double(count), "cold_build_ms": buildMS, "hot_100_reads_ms": hotMS])
            model.homeState.section = "全部歌曲"
            precondition(model.sortedSongs.count == count && !model.homeState.showsRankings, "All Songs exposes the complete library without rankings")
            model.page = .settings; model.page = .library
            precondition(model.homeState.section == "全部歌曲" && !model.homeState.showsRankings && model.cachedLibraryIndex != nil, "Page switch retains home state and index")
        }
        let first = model.tracks[0]
        model.play(first, queue: model.sortedSongs)
        let loads = audio.loadCalls, stops = audio.stopCalls, configurations = audio.configurationCalls
        for _ in 0..<20 { model.page = .settings; model.homeState.section = "歌手列表"; model.page = .player; model.page = .library }
        precondition(model.isPlaying && audio.playing && audio.loadCalls == loads && audio.stopCalls == stops && audio.configurationCalls == configurations, "Navigation must not modify audio graph")
        precondition(model.playbackQueue.count == 10000, "Playback queue includes offscreen tracks")
        let publicationCount = publications.count
        model.collection.searches.append("history only")
        precondition(publications.count == publicationCount && model.cachedLibraryIndex == nil, "Unrelated data does not publish media or rebuild index via artwork")
        model.editSong(first, title: "Current title", artistName: "Current artist")
        precondition(publications.last?.title == "Current title" && publications.last?.artist == "Current artist", "Current metadata publishes without a clock change")
        model.setCover(first.id, data: Data([1, 2, 3]))
        precondition(publications.last?.artwork == Data([1, 2, 3]), "Current cover uses same metadata priority")
        model.setCover(first.id, data: nil)
        precondition(publications.last?.artwork == nil, "Removing cover clears stale system artwork input")
        precondition(model.libraryIndex.metadata[first.id] == model.collection.metadata(for: first), "UI/index and system metadata share one resolver")
        let afterEdit = publications.count
        model.refreshNowPlayingArtwork(); model.refreshNowPlayingArtwork()
        precondition(publications.count == afterEdit, "Repeated identical snapshots are suppressed")
        precondition(audio.loadCalls == loads && audio.stopCalls == stops && audio.configurationCalls == configurations, "Media publication never commands audio")

        model.setRating(first.id, 5)
        precondition(model.songs(in: "stars5").contains { $0.id == first.id }, "Rating invalidates cached automatic categories")
        model.toggleFavorite(first)
        precondition(model.songs(in: "favorites").map(\.id) == [first.id], "Favorite invalidates membership cache")
        model.updateArtist("artist.0", name: "Renamed", avatar: nil)
        precondition(model.libraryIndex.groups["artist.0"]?.name == "Renamed", "Artist rename invalidates index")
        model.collection.songSort = "歌名"
        let sorted = model.sortedSongs
        model.moveSong(sorted[1].id, to: sorted[0].id)
        precondition(model.collection.songSort == "自訂順序" && model.sortedSongs.first?.id == sorted[1].id, "Reordering from a sort captures global order")
        let base = Date()
        let state = model.collection
        let expired = LibraryIndex.build(tracks: model.tracks, collection: state, favorites: [], now: base.addingTimeInterval(8 * 86400))
        precondition(expired.playlistIDs["recent"]?.isEmpty != false, "Seven-day categories rebuild at expiry")
        await model.warmLibraryIndex()
        precondition(model.libraryIndex.tracks.count == 10000, "Background snapshot can warm same complete index")
        model.cachedLibraryIndex?.expiresAt = .distantPast
        var expiryUpdates = 0
        let expiryObserver = model.objectWillChange.sink { expiryUpdates += 1 }
        model.pollPlayback()
        precondition(expiryUpdates == 1 && (model.cachedLibraryIndex?.expiresAt ?? .distantFuture) > Date(), "Expired date categories notify visible UI exactly once")
        model.pollPlayback()
        precondition(expiryUpdates == 1, "Polling an invalid index does not repeatedly invalidate UI")
        expiryObserver.cancel()
        let writer = CollectionWriter()
        let url = root.appendingPathComponent("coalesced.json")
        var written = MusicCollection()
        for i in 0..<1000 {
            written.plays.append(ListeningEvent(trackID: "event.\(i)", date: Date()))
            writer.enqueue(written, to: url) { error in fatalError("Unexpected write failure: " + error) }
        }
        await writer.flush()
        let restored = try JSONDecoder().decode(MusicCollection.self, from: Data(contentsOf: url))
        precondition(restored.plays.count == 1000 && restored.plays.last?.trackID == "event.999", "Coalescing retains every event in latest snapshot and flush waits for it")
        let json = try JSONSerialization.data(withJSONObject: timing, options: [.prettyPrinted, .sortedKeys])
        try json.write(to: work.deletingLastPathComponent().appendingPathComponent("v7-index-timing.json"))
        print("V7 INDEX TIMING " + String(data: json, encoding: .utf8)!)
        print("PASS: V7 1230/5000/10000 track indexes, cache invalidation, unlimited full library, navigation/audio isolation, background warm, sort/reorder and coalesced persistence")
    }
}
