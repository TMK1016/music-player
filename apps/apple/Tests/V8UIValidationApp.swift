import SwiftUI

/// A separate bundle, temporary library and silent backend; never opens private user media.
@MainActor final class ValidationAudio: AudioPlayback {
    var currentTime = 0.0
    var onCompletion: (() -> Void)?
    var onInterruption: ((String) -> Void)?
    func load(_ url: URL) throws { currentTime = 0 }
    func play() throws {}
    func pause() {}
    func seek(to seconds: Double) throws { currentTime = seconds }
    func stop() { currentTime = 0 }
    func configure(gains: [Double], enabled: Bool, volume: Double) {}
    func configureEffects(bass: Double, ambience: Ambience, mix: Double, enabled: Bool) {}
}

@main struct V8UIValidationApp: App {
    @StateObject private var model: PlayerModel
    init() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("music-player-v8-ui-" + UUID().uuidString)
        try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let tracks = (0..<1230).map { i in
            AudioTrack(id: "test.\(i)", title: String(format: "測試歌曲 %04d", i), artist: "歌手 \(i % 100)",
                       collection: "Synthetic", duration: 18, artwork: 0, filename: "silent.wav", sampleRate: 44100, channels: 2, fileType: "WAV")
        }
        let encoded = try! JSONEncoder().encode(tracks)
        let manifest = try! JSONSerialization.data(withJSONObject: ["version": 1, "tracks": JSONSerialization.jsonObject(with: encoded)])
        try! manifest.write(to: root.appendingPathComponent("library.json"))
        var collection = MusicCollection()
        for (i, track) in tracks.enumerated() {
            var detail = SongDetails(); detail.rating = i % 6 == 0 ? nil : i % 6
            detail.addedAt = Date(timeIntervalSince1970: Double(i)); collection.songs[track.id] = detail
        }
        collection.plays = [ListeningEvent(trackID: "test.1229", date: Date())]
        try! JSONEncoder().encode(collection).write(to: root.appendingPathComponent("collection-v1.json"))
        let value = PlayerModel(audio: ValidationAudio(), libraryRoot: root)
        value.homeState.section = "全部歌曲"
        _model = StateObject(wrappedValue: value)
    }
    var body: some Scene {
        WindowGroup("Music Player V8 QA — synthetic/silent") {
            VStack(spacing: 0) {
                HStack {
                    Button("QA 首列") { model.page = .library; model.homeState.section = "全部歌曲"; model.homeState.scrollPositions["全部歌曲"] = "home-top" }
                    Button("QA 末首") { model.page = .library; model.homeState.section = "全部歌曲"; model.homeState.scrollPositions["全部歌曲"] = "all-song:test.1229" }
                }.padding(6)
                ContentView(model: model)
            }.frame(width: 390, height: 780).preferredColorScheme(.dark)
        }.windowResizability(.contentSize)
    }
}
