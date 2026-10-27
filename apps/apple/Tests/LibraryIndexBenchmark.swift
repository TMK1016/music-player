import Foundation
@MainActor private final class BenchAudio: AudioPlayback {
    var currentTime = 0.0
    var onCompletion: (() -> Void)?
    var onInterruption: ((String) -> Void)?
    func load(_ url: URL) throws {}
    func play() throws {}
    func pause() {}
    func stop() {}
    func seek(to seconds: Double) throws {}
    func configure(gains: [Double], enabled: Bool, volume: Double) {}
    func configureEffects(bass: Double, ambience: Ambience, mix: Double, enabled: Bool) {}
}
@main struct LibraryIndexBenchmark {
    @MainActor static func main() throws {
        var results: [[String: Any]] = []
        for count in [1230, 5000, 10000] {
            let model = PlayerModel(audio: BenchAudio(), libraryRoot: FileManager.default.temporaryDirectory.appendingPathComponent("MusicPlayer-Bench-" + UUID().uuidString))
            model.collectionWriteBlocked = true
            var data = MusicCollection()
            data.artists = (0..<200).map { MusicArtist(id: "a\($0)", name: "Artist \($0)") }
            model.tracks = (0..<count).map { AudioTrack(id: "t\($0)", title: "Song \($0)", artist: "本機音檔", collection: "Synthetic", duration: 180, artwork: 0, filename: "not-read.wav", sampleRate: 44100, channels: 2, fileType: "WAV") }
            for i in 0..<count { var info = SongDetails(); info.artistID = "a\(i % 200)"; data.songs["t\(i)"] = info }
            data.plays = (0..<(count * 4)).map { ListeningEvent(trackID: "t\($0 % count)", date: Date()) }
            model.collection = data
            let start = ProcessInfo.processInfo.systemUptime
            let snapshot = model.libraryIndex
            let build = (ProcessInfo.processInfo.systemUptime - start) * 1000
            precondition(snapshot.tracks.count == count && snapshot.totalCounts["t0"] == 4 && snapshot.monthlyRanking.count == count)
            let warm = ProcessInfo.processInfo.systemUptime
            for _ in 0..<100 { precondition(model.libraryIndex.groups.count == 200); precondition(model.playCount("t0", monthly: true) == 4) }
            results.append(["tracks": count, "artists": 200, "events": count * 4, "production_index_build_ms": build, "warm_100_reads_ms": (ProcessInfo.processInfo.systemUptime - warm) * 1000])
        }
        print(String(data: try JSONSerialization.data(withJSONObject: ["scope": "macOS arm64 Swift6 -O; production LibraryIndex; synthetic metadata only, no UI/audio latency", "date": "2026-10-28", "results": results], options: [.prettyPrinted,.sortedKeys]), encoding: .utf8)!)
    }
}
