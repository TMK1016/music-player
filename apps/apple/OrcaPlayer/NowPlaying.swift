import Foundation
#if os(iOS)
import MediaPlayer
import UIKit
#endif

/// Immutable system-media input. Building it never reads or rebuilds LibraryIndex.
struct NowPlayingSnapshot: Equatable {
    let id: String
    let title: String
    let artist: String
    let duration: Double
    let second: Int
    let playing: Bool
    let artwork: Data?
}

/// Owns deduplication, asynchronous artwork and system publication; no audio commands.
@MainActor final class NowPlayingCoordinator {
    private(set) var snapshot: NowPlayingSnapshot?
    private let onPublish: ((NowPlayingSnapshot) -> Void)?
    #if os(iOS)
    private var artwork: MPMediaItemArtwork?
    private var artworkTask: Task<Void, Never>?
    #endif
    init(onPublish: ((NowPlayingSnapshot) -> Void)? = nil) { self.onPublish = onPublish }

    func update(_ value: NowPlayingSnapshot) {
        guard snapshot != value else { return }
        let artworkChanged = snapshot?.id != value.id || snapshot?.artwork != value.artwork
        snapshot = value
        #if os(iOS)
        if artworkChanged {
            artworkTask?.cancel(); artwork = nil
            artworkTask = Task { [weak self] in
                let bitmap = if let data = value.artwork { try? await ArtworkPipeline.shared.decode(data, maxPixelSize: 512) } else { nil as ArtworkBitmap? }
                guard !Task.isCancelled, let self, self.snapshot?.id == value.id, self.snapshot?.artwork == value.artwork else { return }
                let image: UIImage
                if let bitmap { image = UIImage(cgImage: bitmap.image) }
                else {
                    image = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256)).image { context in
                        UIColor(red: 0.06, green: 0.12, blue: 0.21, alpha: 1).setFill(); context.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
                        UIImage(systemName: "music.note")?.withTintColor(.white, renderingMode: .alwaysOriginal).draw(in: CGRect(x: 80, y: 70, width: 96, height: 116))
                    }
                }
                // MediaPlayer invokes this on its own queue. Never capture model/UI state.
                self.artwork = MPMediaItemArtwork(boundsSize: image.size) { @Sendable _ in image }
                self.publish()
            }
        }
        #endif
        publish()
    }
    private func publish() {
        guard let snapshot else { return }
        onPublish?(snapshot)
        #if os(iOS)
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: snapshot.title, MPMediaItemPropertyArtist: snapshot.artist,
            MPMediaItemPropertyPlaybackDuration: snapshot.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(snapshot.second),
            MPNowPlayingInfoPropertyPlaybackRate: snapshot.playing ? 1.0 : 0.0
        ]
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        #endif
    }
}
