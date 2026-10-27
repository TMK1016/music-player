import Foundation
import UniformTypeIdentifiers
import AVFoundation

struct LocalMusicCandidate: Identifiable, Sendable {
    let id: String
    let url: URL
    let duration: Double
    var name: String { url.deletingPathExtension().lastPathComponent }
}
struct LocalMusicScan: Sendable {
    var songs: [LocalMusicCandidate] = []
    var duplicates = 0
    var unavailable = 0
    var reachedLimit = false
}
extension LibraryStore {
    func scanFolder(_ folder: URL) throws -> LocalMusicScan {
        let existing = Set(try load().map(\.id))
        var seen = existing
        var result = LocalMusicScan()
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { throw CocoaError(.fileReadNoPermission) }
        // Common audio suffixes remain discoverable even when UTType registration is unavailable.
        let suffixes: Set<String> = ["wav", "wave", "mp3", "m4a", "aac", "alac", "flac", "aif", "aiff", "aifc", "caf"]
        var checked = 0
        while let url = autoreleasepool(invoking: { enumerator.nextObject() as? URL }) {
            try Task.checkCancellation()
            guard suffixes.contains(url.pathExtension.lowercased()) || UTType(filenameExtension: url.pathExtension)?.conforms(to: .audio) == true else { continue }
            checked += 1
            if checked > 10_000 { result.reachedLimit = true; break }
            do { try autoreleasepool {
                let values = try url.resourceValues(forKeys: keys)
                guard values.isRegularFile == true, values.isSymbolicLink != true else { return }
                if values.isUbiquitousItem == true && values.ubiquitousItemDownloadingStatus != .current && values.ubiquitousItemDownloadingStatus != .downloaded { result.unavailable += 1; return }
                let candidate = try coordinatedCandidate(url)
                if !seen.insert(candidate.id).inserted { result.duplicates += 1; return }
                result.songs.append(candidate)
            } } catch { result.unavailable += 1 }
        }
        result.songs.sort { $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending }
        return result
    }
    private func coordinatedCandidate(_ url: URL) throws -> LocalMusicCandidate {
        var coordinationError: NSError?
        var result: Result<LocalMusicCandidate, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { coordinated in
            result = Result { try readCandidate(coordinated, original: url) }
        }
        if let coordinationError {
            // Local, downloaded files can still be read directly when the file
            // coordination service is unavailable (e.g. a CLI validation host).
            // OS file access checks remain in force. Never bypass cloud coordination.
            if (try? url.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) != true {
                return try readCandidate(url, original: url)
            }
            throw coordinationError
        }

        guard let result else { throw LibraryError.unsupportedAudio }
        return try result.get()
    }
    private func readCandidate(_ url: URL, original: URL) throws -> LocalMusicCandidate {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard file.length > 0, file.length <= Int64(UInt32.max), format.sampleRate > 0, (1...2).contains(format.channelCount) else { throw LibraryError.unsupportedAudio }
        return LocalMusicCandidate(id: try hash(url), url: original, duration: Double(file.length) / format.sampleRate)
    }
}
