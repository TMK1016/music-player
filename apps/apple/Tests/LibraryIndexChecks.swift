import Foundation

@MainActor enum LibraryIndexChecks {
    static func run(work: URL, fixture: URL) async throws {
        let root = work.appendingPathComponent("indexed-library")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: fixture, to: root.appendingPathComponent("fixture.wav"))
        let audio = FakeAudioPlayer()
        let model = PlayerModel(audio: audio, libraryRoot: root, demoURL: fixture)
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
            model.homeState.section = "全部歌曲"; model.homeState.limit = 50
            precondition(model.sortedSongs.prefix(model.homeState.limit).count == 50 && model.sortedSongs.count == count, "Display batch never truncates full queue")
            model.page = .settings; model.page = .library
            precondition(model.homeState.section == "全部歌曲" && model.homeState.limit == 50 && model.cachedLibraryIndex != nil, "Page switch retains home state and index")
        }
        let first = model.tracks[0]
        model.play(first, queue: model.sortedSongs)
        let loads = audio.loadCalls, stops = audio.stopCalls, configurations = audio.configurationCalls
        for _ in 0..<20 { model.page = .settings; model.homeState.section = "歌手列表"; model.page = .player; model.page = .library }
        precondition(model.isPlaying && audio.playing && audio.loadCalls == loads && audio.stopCalls == stops && audio.configurationCalls == configurations, "Navigation must not modify audio graph")
        precondition(model.playbackQueue.count == 10000, "Playback queue includes offscreen tracks")
        model.setRating(first.id, 5)
        precondition(model.songs(in: "stars5").contains { $0.id == first.id }, "Rating invalidates cached automatic categories")
        model.toggleFavorite(first)
        precondition(model.songs(in: "favorites").map(\.id) == [first.id], "Favorite invalidates membership cache")
        model.updateArtist("artist.0", name: "Renamed", avatar: nil)
        precondition(model.artist(first) == "Renamed" && model.libraryIndex.groups["artist.0"]?.name == "Renamed", "Artist rename invalidates index")
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
        print("PASS: V7 1230/5000/10000 track indexes, cache invalidation, full queue vs 50-row display, navigation/audio isolation, background warm, sort/reorder and coalesced persistence")
    }
}
