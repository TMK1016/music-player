import Foundation

/// FIFO snapshots leave JSON encoding and atomic disk writes off the main actor.
final class CollectionWriter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "music-player.collection-writer", qos: .utility)
    func enqueue(_ snapshot: MusicCollection, to url: URL, failure: @escaping @Sendable (String) -> Void) {
        queue.async { autoreleasepool {
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
            } catch { failure(error.localizedDescription) }
        } }
    }
    func flush() async {
        await withCheckedContinuation { continuation in queue.async { continuation.resume() } }
    }
}
