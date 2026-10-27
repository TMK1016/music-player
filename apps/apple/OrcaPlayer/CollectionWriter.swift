import Foundation
import OSLog

/// At most one writing + one latest pending snapshot. All events are already in
/// the immutable state; coalescing does not discard individual listening events.
final class CollectionWriter: @unchecked Sendable {
    private struct Job: Sendable {
        let snapshot: MusicCollection
        let url: URL
        let failure: @Sendable (String) -> Void
    }
    private let queue = DispatchQueue(label: "music-player.collection-writer", qos: .utility)
    private let lock = NSLock()
    private var pending: Job?
    private var scheduled = false
    private let logger = Logger(subsystem: "com.orca.player", category: "storage")
    func enqueue(_ snapshot: MusicCollection, to url: URL, failure: @escaping @Sendable (String) -> Void) {
        let launch = lock.withLock {
            pending = Job(snapshot: snapshot, url: url, failure: failure)
            if scheduled { return false }
            scheduled = true; return true
        }
        if launch { queue.async { self.drain() } }
    }
    private func drain() {
        while true {
            let job: Job? = lock.withLock {
                let job = pending; pending = nil
                if job == nil { scheduled = false }
                return job
            }
            guard let job else { return }
            autoreleasepool {
                do {
                    try FileManager.default.createDirectory(at: job.url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    let data = try JSONEncoder().encode(job.snapshot)
                    try data.write(to: job.url, options: .atomic)
                    logger.debug("Collection snapshot saved, bytes=\(data.count, privacy: .public)")
                } catch { job.failure(error.localizedDescription) }
            }
        }
    }
    func flush() async {
        await withCheckedContinuation { continuation in queue.async { self.drain(); continuation.resume() } }
    }
}
