import Foundation

/// One mutually exclusive policy is shared by transport, completion and UI labels.
enum PlaybackMode: CaseIterable {
    case sequential, repeatOne, repeatAll, shuffle
    var title: String {
        switch self {
        case .sequential: "順序播放"
        case .repeatOne: "單曲循環"
        case .repeatAll: "歌單循環"
        case .shuffle: "隨機播放"
        }
    }
    var symbol: String {
        switch self {
        case .sequential: "arrow.right"
        case .repeatOne: "repeat.1"
        case .repeatAll: "repeat"
        case .shuffle: "shuffle"
        }
    }
}

extension PlayerModel {
    // Compatibility accessors for existing controls; impossible combinations cannot persist.
    var repeatOne: Bool {
        get { playbackMode == .repeatOne }
        set { if newValue { playbackMode = .repeatOne } else if repeatOne { playbackMode = .sequential } }
    }
    var repeatAll: Bool {
        get { playbackMode == .repeatAll }
        set { if newValue { playbackMode = .repeatAll } else if repeatAll { playbackMode = .sequential } }
    }
    var shuffle: Bool {
        get { playbackMode == .shuffle }
        set { if newValue { playbackMode = .shuffle } else if shuffle { playbackMode = .sequential } }
    }
    func setPlaybackMode(_ label: String) {
        switch label {
        case "順序播放": playbackMode = .sequential
        case "單曲循環", "單曲重複": playbackMode = .repeatOne
        case "歌單循環", "清單循環": playbackMode = .repeatAll
        case "隨機播放": playbackMode = .shuffle
        default: break
        }
    }
    func cyclePlaybackMode() {
        playbackMode = shuffle ? .repeatAll : repeatOne ? .shuffle : .repeatOne
    }
    var queueTracks: [AudioTrack] {
        guard !playbackQueue.isEmpty else { return tracks }
        let index = libraryIndex
        return playbackQueue.compactMap { index.tracks[$0] }
    }
}
