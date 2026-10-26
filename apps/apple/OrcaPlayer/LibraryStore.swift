import Foundation
import AVFoundation
import CryptoKit

struct AudioTrack: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let title: String
    let artist: String
    let collection: String
    let duration: Double
    let artwork: Int
    let filename: String?
    let sampleRate: Double
    let channels: UInt32
    let fileType: String
    var isDemo: Bool { filename == nil }
    var formatLabel: String { "\(fileType) · \(String(format: "%.1f", sampleRate / 1000)) kHz · \(channels == 1 ? "Mono" : "Stereo")" }
    static let demo = AudioTrack(id: "orca-soundcheck", title: "Music Player Soundcheck", artist: "Music Player · 原創測試片段", collection: "本機示範", duration: 18, artwork: 0, filename: nil, sampleRate: 44_100, channels: 2, fileType: "WAV")
}

private struct LibraryManifest: Codable {
    var version = 1
    var tracks: [AudioTrack]
}
struct ImportResult: Sendable {
    var tracks: [AudioTrack]
    var added: Int
    var duplicates: Int
    var failures: [String]
}
enum LibraryError: LocalizedError {
    case corruptManifest, unsupportedAudio, cloudUnavailable
    var errorDescription: String? {
        switch self {
        case .corruptManifest: "音樂庫索引無法讀取。為保留既有資料，已停止寫入；請先備份音樂庫再修復索引。"
        case .unsupportedAudio: "無法解碼此音檔，或聲道數不在目前支援的 1～2 聲道範圍。"
        case .cloudUnavailable: "此雲端檔案尚未下載完成，請先在「檔案」或 Finder 下載後再匯入。"
        }
    }
}

/// Serializes imports and manifest commits. Source files are never moved/deleted.
actor LibraryStore {
    let root: URL
    private var tracks: [AudioTrack] = []
    private var loaded = false
    init(root: URL) { self.root = root }
    func load() throws -> [AudioTrack] {
        if loaded { return tracks }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let manifest = root.appendingPathComponent("library.json")
        if FileManager.default.fileExists(atPath: manifest.path) {
            guard let data = try? Data(contentsOf: manifest), let decoded = try? JSONDecoder().decode(LibraryManifest.self, from: data), decoded.version == 1,
                  Set(decoded.tracks.map(\.id)).count == decoded.tracks.count,
                  decoded.tracks.allSatisfy({ t in
                      guard let filename = t.filename else { return false }
                      return filename == URL(fileURLWithPath: filename).lastPathComponent && !filename.hasPrefix(".") && t.duration.isFinite && t.duration > 0 && t.sampleRate.isFinite && t.sampleRate > 0 && (1...2).contains(t.channels)
                  }) else { throw LibraryError.corruptManifest }
            tracks = decoded.tracks
        }
        loaded = true
        return tracks
    }
    func importFiles(_ urls: [URL]) throws -> ImportResult {
        _ = try load()
        var added = 0, duplicates = 0
        var failures: [String] = []
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let values = try url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
                if values.isUbiquitousItem == true && values.ubiquitousItemDownloadingStatus == .notDownloaded { throw LibraryError.cloudUnavailable }
                let audio = try AVAudioFile(forReading: url)
                let format = audio.processingFormat
                guard audio.length > 0, audio.length <= Int64(UInt32.max), format.sampleRate > 0, (1...2).contains(format.channelCount),
                      let probe = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(min(4096, audio.length))) else { throw LibraryError.unsupportedAudio }
                try audio.read(into: probe)
                guard probe.frameLength > 0 else { throw LibraryError.unsupportedAudio }
                let digest = try hash(url)
                if tracks.contains(where: { $0.id == digest }) { duplicates += 1; continue }
                let suffix = url.pathExtension.lowercased().filter { $0.isLetter || $0.isNumber }
                let filename = digest + (suffix.isEmpty ? ".audio" : "." + suffix)
                let target = root.appendingPathComponent(filename)
                var copied = false
                if !FileManager.default.fileExists(atPath: target.path) {
                    let staging = root.appendingPathComponent(".import-" + UUID().uuidString)
                    defer { try? FileManager.default.removeItem(at: staging) }
                    try FileManager.default.copyItem(at: url, to: staging)
                    // Check the copied bytes, not just the original, before committing.
                    guard try hash(staging) == digest else { throw LibraryError.unsupportedAudio }
                    try FileManager.default.moveItem(at: staging, to: target)
                    copied = true
                } else {
                    guard try hash(target) == digest else { throw LibraryError.corruptManifest }
                }
                let track = AudioTrack(id: digest, title: url.deletingPathExtension().lastPathComponent, artist: "本機音檔", collection: "我的音樂", duration: Double(audio.length) / format.sampleRate, artwork: tracks.count % 5, filename: filename, sampleRate: format.sampleRate, channels: format.channelCount, fileType: suffix.uppercased())
                tracks.append(track)
                do {
                    let data = try JSONEncoder().encode(LibraryManifest(tracks: tracks))
                    try data.write(to: root.appendingPathComponent("library.json"), options: .atomic)
                } catch {
                    tracks.removeLast()
                    if copied { try? FileManager.default.removeItem(at: target) }
                    throw error
                }
                added += 1
            } catch { failures.append("\(url.lastPathComponent)：\(error.localizedDescription)") }
        }
        return ImportResult(tracks: tracks, added: added, duplicates: duplicates, failures: failures)
    }
    private func hash(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty { hasher.update(data: data) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
