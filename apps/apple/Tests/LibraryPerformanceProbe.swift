import Foundation

@MainActor private final class ProbeAudio: AudioPlayback {
    var currentTime = 0.0
    var onCompletion: (() -> Void)?
    var onInterruption: ((String) -> Void)?
    func load(_ url: URL) throws {}
    func play() throws {}
    func pause() {}
    func seek(to seconds: Double) throws {}
    func stop() {}
    func configure(gains: [Double], enabled: Bool, volume: Double) {}
    func configureEffects(bass: Double, ambience: Ambience, mix: Double, enabled: Bool) {}
}

/// Assessment-only probe. Replicates current view calculations without building UI
/// or touching a user's library. Candidate aggregate is not wired into the product.
@main struct LibraryPerformanceProbe {
    @MainActor static func currentGroups(_ model: PlayerModel) -> [String] {
        let names = Set(model.tracks.map { model.artist($0) })
        return names.sorted { a, b in
            let left = model.tracks.filter { model.artist($0) == a }
            let right = model.tracks.filter { model.artist($0) == b }
            if left.count != right.count { return left.count > right.count }
            return a.compare(b, options: [.numeric], locale: Locale(identifier: "zh_Hant_TW@collation=stroke")) == .orderedAscending
        }
    }
    @MainActor static func currentRanking(_ model: PlayerModel) -> [String] {
        model.tracks.filter { model.playCount($0.id, monthly: true) > 0 }.sorted {
            let a = model.playCount($0.id, monthly: true), b = model.playCount($1.id, monthly: true)
            return a == b ? model.title($0) < model.title($1) : a > b
        }.map(\.id)
    }
    struct Candidate {
        let groups: [String]
        let ranking: [String]
    }
    @MainActor static func aggregateCandidate(_ model: PlayerModel) -> Candidate {
        let artists = Dictionary(uniqueKeysWithValues: model.collection.artists.map { ($0.id, $0.name) })
        var grouped: [String: Int] = [:]
        var titles: [String: String] = [:]
        for track in model.tracks {
            let info = model.collection.songs[track.id]
            let artist = info?.artistID.flatMap { artists[$0] } ?? (track.artist == "本機音檔" ? "未知歌手" : track.artist)
            grouped[artist, default: 0] += 1
            titles[track.id] = info?.title ?? track.title
        }
        let groups = grouped.keys.sorted {
            let a = grouped[$0]!, b = grouped[$1]!
            return a != b ? a > b : $0.compare($1, options: [.numeric], locale: Locale(identifier: "zh_Hant_TW@collation=stroke")) == .orderedAscending
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        let now = Date()
        var counts: [String: Int] = [:]
        for play in model.collection.plays where calendar.isDate(play.date, equalTo: now, toGranularity: .month) {
            counts[play.trackID, default: 0] += 1
        }
        let ranking = model.tracks.filter { counts[$0.id, default: 0] > 0 }.sorted {
            let a = counts[$0.id, default: 0], b = counts[$1.id, default: 0]
            return a != b ? a > b : titles[$0.id]! < titles[$1.id]!
        }.map(\.id)
        return Candidate(groups: groups, ranking: ranking)
    }
    @MainActor static func measure<T>(_ action: () -> T) -> (T, Double) {
        let start = ProcessInfo.processInfo.systemUptime
        let result = action()
        return (result, (ProcessInfo.processInfo.systemUptime - start) * 1000)
    }
    @MainActor static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MusicPlayer-V7-Probe-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var rows: [[String: Any]] = []
        for (count, artistCount, events) in [(150, 10, 600), (1230, 100, 0), (1230, 100, 4920), (1230, 200, 4920)] {
            let model = PlayerModel(audio: ProbeAudio(), libraryRoot: root)
            model.collectionWriteBlocked = true
            model.tracks = (0..<count).map { i in AudioTrack(id: "probe.\(i)", title: "Song \(i)", artist: "本機音檔", collection: "Synthetic", duration: 240, artwork: 0, filename: "never-read.wav", sampleRate: 44100, channels: 2, fileType: "WAV") }
            var collection = MusicCollection()
            collection.artists = (0..<artistCount).map { MusicArtist(id: "artist.\($0)", name: "測試歌手 \($0)") }
            for i in 0..<count { var details = SongDetails(); details.artistID = collection.artists[i % artistCount].id; collection.songs[model.tracks[i].id] = details }
            collection.plays = (0..<events).map { ListeningEvent(trackID: model.tracks[$0 % count].id, date: Date()) }
            model.collection = collection
            let (groups, groupsMS) = measure { currentGroups(model) }
            let (ranking, rankingMS) = measure { currentRanking(model) }
            let (candidate, candidateMS) = measure { aggregateCandidate(model) }
            precondition(groups == candidate.groups && ranking == candidate.ranking, "Candidate must preserve reference results")
            rows.append(["tracks": count, "artists": artistCount, "events": events, "current_artist_groups_ms": groupsMS, "current_monthly_ranking_ms": rankingMS, "candidate_combined_aggregation_ms": candidateMS, "equivalent_results": true])
        }
        let result: [String: Any] = ["scope": "macOS arm64 CLI -O; one synthetic sample per case; view computations only, not device/UI/audio measurements", "date": "2026-10-28", "rows": rows]
        print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
    }
}
