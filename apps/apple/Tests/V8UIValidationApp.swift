import SwiftUI
import ImageIO
import UniformTypeIdentifiers

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
            AudioTrack(id: "test.\(i)", title: i == 0 ? "超長歌曲名稱 Long English Title 日本語 한국어 " + String(repeating: "測試完整歌名 ", count: 12) : String(format: "測試歌曲 %04d", i), artist: "歌手 \(i % 100)",
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
        let blue = Self.cover(red: 0.05, green: 0.4, blue: 0.95)
        let orange = Self.cover(red: 1, green: 0.42, blue: 0.05)
        collection.artists = [MusicArtist(id: "qa.blue", name: "歌手 0", avatar: blue), MusicArtist(id: "qa.orange", name: "歌手 1", avatar: orange)]
        collection.playlistAppearance = ["stars5": PlaylistAppearance(name: nil, artwork: blue), "stars4": PlaylistAppearance(name: nil, artwork: orange)]
        collection.plays = [ListeningEvent(trackID: "test.1229", date: Date())]
        try! JSONEncoder().encode(collection).write(to: root.appendingPathComponent("collection-v1.json"))
        let value = PlayerModel(audio: ValidationAudio(), libraryRoot: root)
        value.homeState.section = "全部歌曲"
        _model = StateObject(wrappedValue: value)
    }
    private static func cover(red: CGFloat, green: CGFloat, blue: CGFloat) -> Data {
        let context = CGContext(data: nil, width: 128, height: 128, bitsPerComponent: 8, bytesPerRow: 512, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
        let bytes = NSMutableData()
        let destination = CGImageDestinationCreateWithData(bytes, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil); precondition(CGImageDestinationFinalize(destination))
        return bytes as Data
    }
    var body: some Scene {
        WindowGroup("Music Player V8 QA — synthetic/silent") {
            VStack(spacing: 0) {
                HStack {
                    Button("QA 首列") { model.page = .library; model.homeState.section = "全部歌曲"; model.homeState.requestScroll() }
                    Button("QA 末首") { model.page = .library; model.homeState.section = "全部歌曲"; model.homeState.requestScroll(to: 200_000) }
                }.padding(6)
                ContentView(model: model)
            }.frame(width: 390, height: 780).preferredColorScheme(.dark)
        }.windowResizability(.contentSize)
    }
}
