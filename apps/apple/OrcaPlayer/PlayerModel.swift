import Foundation
import Combine
#if os(iOS)
import MediaPlayer
import UIKit
#endif

enum PlayerPage: String, CaseIterable, Identifiable {
    case settings = "設定", player = "正在播放", library = "首頁", equalizer = "等化器", developmentLog = "開發日誌"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .settings: "gearshape"
        case .player: "waveform"
        case .library: "square.stack"
        case .equalizer: "slider.vertical.3"
        case .developmentLog: "clock.arrow.circlepath"
        }
    }
    static func destination(for identifier: String?) -> PlayerPage? {
        switch identifier {
        case "settings": .settings
        case "player": .player
        case "library": .library
        case "equalizer": .equalizer
        case "developmentLog": .developmentLog
        default: nil
        }
    }
}

enum EQPreset: String, CaseIterable, Identifiable {
    case flat = "原聲", bass = "低頻", vocal = "人聲", night = "夜間", pop = "流行", rock = "搖滾", jazz = "爵士", classical = "古典", electronic = "電子", acoustic = "木吉他", podcast = "語音", warm = "溫暖", concert = "演唱會"
    var id: String {
        switch self {
        case .flat: "builtin.flat"
        case .bass: "builtin.bass"
        case .vocal: "builtin.vocal"
        case .night: "builtin.night"
        case .pop: "builtin.pop"
        case .rock: "builtin.rock"
        case .jazz: "builtin.jazz"
        case .classical: "builtin.classical"
        case .electronic: "builtin.electronic"
        case .acoustic: "builtin.acoustic"
        case .podcast: "builtin.podcast"
        case .warm: "builtin.warm"
        case .concert: "builtin.concert"
        }
    }
    var gains: [Double] {
        switch self {
        case .flat: EQBands.flat
        case .bass: [3.5, 2, 0, -1, 0, 1, 1]
        case .vocal: [-1, 0, 1, 2, 2.5, 0, -1]
        case .night: [-3, -1, 0, 1, 0, -1, -2]
        case .pop: [1, 1, -1, 0.5, 2, 1, 0]
        case .rock: [2, 1, -1, 0, 2, 1.5, 0]
        case .jazz: [0.5, 1, 0, 0.5, 1, 0, 1]
        case .classical: [0, 0, -0.5, 0, 0.5, 1, 0.5]
        case .electronic: [3, 1, -1, 0, 1, 2, 1]
        case .acoustic: [-1.5, 0, 1, 1.5, 1.5, 0.5, -0.5]
        case .podcast: [-3, -1, 1, 2, 1.5, -1, -2]
        case .warm: [1.5, 2, 0.5, 0, -0.5, -1, -2]
        case .concert: [0.5, 0, -1, 0, 1, 0.5, 0]
        }
    }
}

private struct SavedSettings: Codable {
    var version = 3
    var gains: [Double]
    var eqEnabled: Bool
    var volume: Double
    var favorites: Set<String>
    var bass: Double? = nil
    var ambience: Ambience? = nil
    var mix: Double? = nil
    var customs: [CustomPreset]? = nil
    var bindings: [String: String]? = nil
    var hiddenPresets: Set<String>? = nil
    var useSongProfiles: Bool? = nil
    var modeOrder: [String]? = nil
}

@MainActor final class PlayerModel: ObservableObject {
    @Published var collection = MusicCollection() { didSet { invalidateLibraryIndex(); persistCollection(); refreshNowPlayingArtwork() } }
    let collectionWriter = CollectionWriter()
    var collectionWriteBlocked = false
    @Published var playbackMode: PlaybackMode = .repeatAll
    @Published private(set) var hasPlaybackSession = false
    @Published var sleepDeadline: Date?
    @Published var sleepSongsRemaining: Int?
    @Published var useSongProfiles = true
    var playbackQueue: [String] = []
    @Published var playbackListID: String?
    @Published var playbackContextName = "全部歌曲"
    private var listened = 0.0
    private var counted = false
    private var lastSample = 0.0
    private var lastTick = ProcessInfo.processInfo.systemUptime
    static let frequencies = EQBands.labels
    @Published var page: PlayerPage = .library { didSet { PlayerDiagnostics.event("Page:" + page.id) } }
    @Published var search = ""
    @Published var showLibrarySearch = false
    @Published var favoritesOnly = false
    @Published var tracks: [AudioTrack] = [.demo] { didSet { invalidateLibraryIndex() } }
    @Published var selectedID = AudioTrack.demo.id
    @Published var isPlaying = false { didSet { updateNowPlaying() } }
    let playbackClock = PlaybackClock()
    private(set) var currentTime: Double {
        get { playbackClock.time }
        set { if playbackClock.time != newValue { playbackClock.time = newValue } }
    }
    @Published private(set) var isImporting = false
    @Published var showImporter = false
    @Published var volume = 0.5 { didSet { syncAudio(); save() } }
    @Published var eqEnabled = true {
        didSet {
            guard !applying else { return }
            if !eqEnabled {
                // The master switch discards the current adjustment, but not saved presets.
                unboundSound = nil
                var original = SoundProfile.flat
                original.enabled = false
                setSound(original)
            } else { syncAudio(); save() }
        }
    }
    @Published var gains = EQPreset.flat.gains { didSet { syncAudio(); save() } }
    @Published var favorites: Set<String> = [] { didSet { invalidateLibraryIndex(); save() } }
    @Published var message: String?
    /// SwiftUI can reset an alert binding during reconciliation. Publish only
    /// after that stack unwinds, and never dismiss a newer, different message.
    @discardableResult func dismissMessage() -> Task<Void, Never>? {
        guard let displayed = message else { return nil }
        return Task { @MainActor [weak self] in
            guard let self, self.message == displayed else { return }
            self.message = nil
        }
    }
    @Published var showQueue = false
    @Published var bassBoost = 0.0 { didSet { syncAudio(); save() } }
    @Published var ambience: Ambience = .off { didSet { syncAudio(); save() } }
    @Published var ambienceMix = 15.0 { didSet { syncAudio(); save() } }
    @Published private(set) var customPresets: [CustomPreset] = []
    @Published var songBindings: [String: String] = [:]
    @Published var presetError: String?
    @Published var presetInput = ""
    @Published var showPresetEditor = false
    @Published private(set) var hasManualEQChanges = false
    private var manualEQBaseline: SoundProfile?
    @Published private(set) var modeOrder: [String] = []
    @Published private(set) var hiddenPresets: Set<String> = []
    @Published var editingPresetID: String?
    @Published var pendingDeleteID: String?
    private var unboundSound: SoundProfile?
    private var applying = false
    @Published var selectedLogChangeID: String?
    @Published private(set) var importSummary = ""
    let nowPlaying: NowPlayingCoordinator
    let audio: any AudioPlayback
    let library: LibraryStore
    let libraryRoot: URL
    private let demoURL: URL?
    private let onSave: ((Data) -> Void)?
    private var timer: AnyCancellable?
    var loadedID: String?
    private var playbackRequest: UUID?
    private var libraryLoaded = false
    private var installingLibraryIndex = false
    var libraryInstallGeneration = 0
    var cachedLibraryIndex: LibraryIndex?
    var indexRevision = 0
    let homeState = HomeLibraryState()

    init(savedData: Data? = nil, onSave: ((Data) -> Void)? = nil, audio: (any AudioPlayback)? = nil, libraryRoot: URL? = nil, demoURL: URL? = nil, nowPlaying: NowPlayingCoordinator? = nil) {
        self.nowPlaying = nowPlaying ?? NowPlayingCoordinator()
        self.onSave = onSave
        self.audio = audio ?? NativeAudioPlayer()
        self.libraryRoot = libraryRoot ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("OrcaPlayer/Library", isDirectory: true)
        library = LibraryStore(root: self.libraryRoot)
        self.demoURL = demoURL ?? Bundle.main.url(forResource: "Orca-Soundcheck", withExtension: "wav")
        applying = true
        if let savedData, let settings = try? JSONDecoder().decode(SavedSettings.self, from: savedData), (1...3).contains(settings.version) {
            gains = EQBands.migrate(settings.gains)
            volume = settings.volume.isFinite ? min(1, max(0, settings.volume)) : 0.5
            eqEnabled = settings.eqEnabled
            favorites = settings.favorites
            bassBoost = min(9, max(0, settings.bass ?? 0))
            ambience = settings.ambience ?? .off
            ambienceMix = min(35, max(0, settings.mix ?? 15))
            var names = Set<String>(); var ids = Set<String>()
            customPresets = (settings.customs ?? []).filter {
                !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.name.count <= 30 &&
                $0.id.hasPrefix("custom.") && ids.insert($0.id).inserted && names.insert($0.name.lowercased()).inserted
            }.prefix(20).map { CustomPreset(id: $0.id, name: $0.name, sound: $0.sound.sanitized) }
            hiddenPresets = (settings.hiddenPresets ?? []).intersection(Set(EQPreset.allCases.map(\.id)))
            let valid = Set(EQPreset.allCases.map(\.id).filter { !hiddenPresets.contains($0) } + customPresets.map(\.id))
            songBindings = (settings.bindings ?? [:]).filter { valid.contains($0.value) }
            useSongProfiles = settings.useSongProfiles ?? true
            var seenOrder = Set<String>()
            modeOrder = (settings.modeOrder ?? []).filter { valid.contains($0) && seenOrder.insert($0).inserted }
        }
        if !eqEnabled {
            gains = EQBands.flat; bassBoost = 0; ambience = .off; ambienceMix = SoundProfile.flat.mix
        }
        applying = false
        self.audio.onCompletion = { [weak self] in self?.handleCompletion() }
        self.audio.onInterruption = { [weak self] message in
            guard let self else { return }
            self.playbackRequest = nil
            self.accountPlayback()
            self.currentTime = self.audio.currentTime
            self.isPlaying = false
            PlayerDiagnostics.event("AudioInterrupted")
        }
        let collectionURL = self.libraryRoot.appendingPathComponent("collection-v1.json")
        if FileManager.default.fileExists(atPath: collectionURL.path) {
            do {
                let data = try Data(contentsOf: collectionURL)
                let decoded = try JSONDecoder().decode(MusicCollection.self, from: data)
                guard decoded.version == 1,
                      decoded.songs.values.allSatisfy({ $0.rating == nil || (1...5).contains($0.rating!) }),
                      Set(decoded.artists.map(\.id)).count == decoded.artists.count,
                      Set(decoded.playlists.map(\.id)).count == decoded.playlists.count else { throw LibraryError.corruptManifest }
                collection = decoded
            } catch { collectionWriteBlocked = true; message = "分類資料無法讀取，已保留原檔並停止覆寫。" }
        }
        installRemoteCommands()
        applySongBinding()
        syncAudio()
        timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.pollPlayback()
            }
        }
    }
    var track: AudioTrack { libraryIndex.tracks[selectedID] ?? .demo }
    var filteredTracks: [AudioTrack] {
        tracks.filter {
            (!favoritesOnly || favorites.contains($0.id)) &&
            (search.isEmpty || "\(title($0)) \(artist($0)) \($0.collection)".localizedCaseInsensitiveContains(search))
        }
    }
    var progress: Double {
        get { min(1, max(0, currentTime / track.duration)) }
        set {
            guard newValue.isFinite else { return }
            seek(to: min(1, max(0, newValue)) * track.duration)
        }
    }
    var sound: SoundProfile { SoundProfile(gains: gains, enabled: eqEnabled, bass: bassBoost, ambience: ambience, mix: ambienceMix).sanitized }
    func openHome() {
        homeState.returnToRoot()
        showLibrarySearch = false
        search = ""
        page = .library
    }
    var presetName: String {
        guard eqEnabled else { return EQPreset.flat.rawValue }
        if let custom = customPresets.first(where: { $0.sound == sound }) { return custom.name }
        return EQPreset.allCases.first { !hiddenPresets.contains($0.id) && profile(for: $0.id) == sound }?.rawValue ?? "手動調音"
    }
    var elapsed: String { Self.time(currentTime) }
    var remaining: String { "−" + Self.time(max(0, track.duration - currentTime)) }
    var headroomDB: Float { EQHeadroom.gain(gains: gains, bass: sound.bass, sampleRate: track.sampleRate, ambience: ambience, mix: sound.mix) }
    var statusText: String { isPlaying ? "正在播放 · \(track.formatLabel)" : "本機離線播放器 · 匯入音檔後即可播放與調音" }
    var settingsData: Data? {
        let base = unboundSound ?? sound
        return try? JSONEncoder().encode(SavedSettings(gains: base.gains, eqEnabled: base.enabled, volume: volume, favorites: favorites, bass: base.bass, ambience: base.ambience, mix: base.mix, customs: customPresets, bindings: songBindings, hiddenPresets: hiddenPresets, useSongProfiles: useSongProfiles, modeOrder: modeOrder))
    }

    func loadLibrary() async {
        guard !libraryLoaded else { return }
        libraryLoaded = true
        libraryInstallGeneration += 1
        let generation = libraryInstallGeneration
        do { await installLibraryTracks([.demo] + (try await library.load()), markImported: false, generation: generation) }
        catch { message = error.localizedDescription }
    }
    func importFiles(_ urls: [URL]) async {
        guard !isImporting else { return }
        isImporting = true
        libraryInstallGeneration += 1
        let generation = libraryInstallGeneration
        defer { isImporting = false }
        do {
            let result = try await library.importFiles(urls)
            await installLibraryTracks([.demo] + result.tracks, markImported: true, generation: generation)
            importSummary = "新增 \(result.added) 首，略過 \(result.duplicates) 首重複音檔"
            if !result.failures.isEmpty { message = importSummary + "\n\n" + result.failures.joined(separator: "\n") }
            else if result.added == 0 { message = importSummary }
        } catch { message = error.localizedDescription }
    }
    private func installLibraryTracks(_ newTracks: [AudioTrack], markImported: Bool, generation: Int) async {
        while generation == libraryInstallGeneration {
            let revision = indexRevision
            var state = collection
            if markImported { for track in newTracks where !track.isDemo && state.songs[track.id] == nil { state.songs[track.id] = SongDetails() } }
            let snapshotState = state, snapshotFavorites = favorites
            let index = await Task.detached(priority: .utility) { LibraryIndex.build(tracks: newTracks, collection: snapshotState, favorites: snapshotFavorites) }.value
            guard generation == libraryInstallGeneration else { return }
            guard revision == indexRevision else { continue }
            // Publish one coherent generation after background preparation. UI never
            // sees new tracks paired with an old or half-built metadata index.
            installingLibraryIndex = true
            tracks = newTracks
            if markImported { collection = state }
            cachedLibraryIndex = index
            installingLibraryIndex = false
            refreshNowPlayingArtwork()
            PlayerDiagnostics.event("LibraryReady:tracks=\(newTracks.count)")
            return
        }
    }
    func choose(_ track: AudioTrack, autoplay: Bool = true) {
        playbackRequest = nil
        accountPlayback()
        audio.stop()
        loadedID = nil
        isPlaying = false
        selectedID = track.id
        listened = 0; counted = false; lastSample = 0; lastTick = ProcessInfo.processInfo.systemUptime
        applySongBinding()
        currentTime = 0
        refreshNowPlayingArtwork()
        if autoplay { start() }
    }
    func togglePlayback() {
        if isPlaying || playbackRequest != nil { pausePlayback() }
        else { start() }
    }
    func pausePlayback() {
        playbackRequest = nil
        if isPlaying {
            accountPlayback()
            currentTime = audio.currentTime
        }
        audio.pause()
        isPlaying = false
    }
    private func start() {
        if expireSleepTimer() { return }
        let request = UUID()
        playbackRequest = request
        audio.prepareForPlayback { [weak self] result in
            guard let self, self.playbackRequest == request else { return }
            self.playbackRequest = nil
            if self.expireSleepTimer() { return }
            switch result {
            case .success: self.startPreparedPlayback()
            case .failure(let error): self.isPlaying = false; self.message = error.localizedDescription
            }
        }
    }
    private func startPreparedPlayback() {
        do {
            if loadedID != selectedID {
                let url: URL
                if let filename = track.filename { url = libraryRoot.appendingPathComponent(filename) }
                else if let demoURL { url = demoURL }
                else { throw PlaybackError.missingFile }
                try audio.load(url)
                loadedID = selectedID
                try audio.seek(to: currentTime >= track.duration - 0.02 ? 0 : currentTime)
            } else if currentTime >= track.duration - 0.02 {
                try audio.seek(to: 0)
                currentTime = 0
                listened = 0; counted = false
            }
            syncAudio()
            try audio.play()
            isPlaying = true
            hasPlaybackSession = true
            refreshNowPlayingArtwork()
            lastSample = audio.currentTime; lastTick = ProcessInfo.processInfo.systemUptime
        } catch {
            isPlaying = false
            message = error.localizedDescription
        }
    }
    func seek(to seconds: Double) {
        guard seconds.isFinite else { return }
        accountPlayback()
        currentTime = min(track.duration, max(0, seconds))
        if loadedID == selectedID {
            do { try audio.seek(to: currentTime); lastSample = currentTime; lastTick = ProcessInfo.processInfo.systemUptime }
            catch { isPlaying = false; message = error.localizedDescription }
        }
    }
    func next() { advance(forward: true) }
    func previous() {
        if currentTime > 3 { choose(track, autoplay: isPlaying || playbackRequest != nil) } else { advance(forward: false) }
    }
    func play(_ track: AudioTrack, queue: [AudioTrack], contextName: String = "全部歌曲", playlistID: String? = nil) {
        playbackListID = playlistID; playbackContextName = contextName
        playbackQueue = queue.map(\.id); choose(track)
    }
    private func advance(forward: Bool) {
        let queue = queueTracks
        guard !queue.isEmpty else { return }
        let index = queue.firstIndex(where: { $0.id == selectedID }) ?? 0
        let offset = shuffle && queue.count > 1 ? Int.random(in: 1..<queue.count) : (forward ? 1 : queue.count - 1)
        choose(queue[(index + offset) % queue.count], autoplay: isPlaying || playbackRequest != nil)
    }
    private func handleCompletion() { finishedTrack() }
    private func finishedTrack() {
        accountPlayback(finalPosition: track.duration)
        currentTime = track.duration
        if let left = sleepSongsRemaining {
            sleepSongsRemaining = max(0, left - 1)
            if left <= 1 { stopForSleep(); return }
        }
        if expireSleepTimer() { return }
        if repeatOne { choose(track); return }
        let ids = queueTracks.map(\.id)
        if repeatAll || shuffle || ids.last != selectedID { advance(forward: true) }
        else { isPlaying = false }
    }
    func scheduleSleep(minutes: Int? = nil, songs: Int? = nil) {
        if let minutes {
            sleepDeadline = Date().addingTimeInterval(Double(min(120, max(1, minutes))) * 60)
            sleepSongsRemaining = nil
        } else if let songs {
            sleepDeadline = nil
            sleepSongsRemaining = min(100, max(1, songs))
        } else { cancelSleep() }
    }
    var sleepStatus: String {
        if let left = sleepSongsRemaining { return "剩餘\(left)首" }
        if let deadline = sleepDeadline { return "\(deadline.formatted(date: .omitted, time: .shortened)) 停止" }
        return "未設定"
    }
    func cancelSleep() { sleepDeadline = nil; sleepSongsRemaining = nil }
    private func stopForSleep() {
        playbackRequest = nil
        audio.pause(); isPlaying = false; cancelSleep(); message = "已達聆聽設定，播放已暫停。"
    }
    @discardableResult private func expireSleepTimer() -> Bool {
        if let deadline = sleepDeadline, Date() >= deadline { stopForSleep(); return true }
        return false
    }
    func pollPlayback(now: Double = ProcessInfo.processInfo.systemUptime) {
        if let index = cachedLibraryIndex, Date() >= index.expiresAt {
            invalidateLibraryIndex()
            objectWillChange.send()
        }
        if isPlaying { accountPlayback(now: now); currentTime = audio.currentTime }
        _ = expireSleepTimer()
        updateNowPlaying()
    }
    private func accountPlayback(now: Double = ProcessInfo.processInfo.systemUptime, finalPosition: Double? = nil) {
        guard isPlaying else { return }
        let position = finalPosition ?? audio.currentTime
        let delta = max(0, position - lastSample)
        listened += min(delta, max(0, now - lastTick) + 0.05)
        lastSample = position; lastTick = now
        if !counted, listened > track.duration / 2 {
            counted = true; collection.plays.append(ListeningEvent(trackID: selectedID, date: Date()))
        }
    }
    func toggleFavorite(_ track: AudioTrack) {
        if favorites.contains(track.id) { favorites.remove(track.id) } else { favorites.insert(track.id) }
    }
    var modeOptions: [ModeOption] {
        let options = EQPreset.allCases.filter { !hiddenPresets.contains($0.id) }.map { ModeOption(id: $0.id, name: $0.rawValue, isCustom: false) } + customPresets.map { ModeOption(id: $0.id, name: $0.name, isCustom: true) }
        let ranks = Dictionary(uniqueKeysWithValues: modeOrder.enumerated().map { ($0.element, $0.offset) })
        return options.enumerated().sorted { (ranks[$0.element.id] ?? (modeOrder.count + $0.offset)) < (ranks[$1.element.id] ?? (modeOrder.count + $1.offset)) }.map(\.element)
    }
    func moveMode(_ id: String, by offset: Int) {
        var ids = modeOptions.map(\.id)
        guard let index = ids.firstIndex(of: id), ids.indices.contains(index + offset) else { return }
        let moved = ids.remove(at: index); ids.insert(moved, at: index + offset); modeOrder = ids; save()
    }
    func adjustBass(to value: Double) {
        guard eqEnabled, value.isFinite else { return }
        let next = min(9, max(0, value.rounded()))
        guard next != bassBoost else { return }
        if manualEQBaseline == nil { manualEQBaseline = sound }
        bassBoost = next
        updateManualChanges()
    }
    private func updateManualChanges() {
        hasManualEQChanges = manualEQBaseline.map { sound != $0 } ?? false
        if !hasManualEQChanges { manualEQBaseline = nil }
    }
    func removeMode(_ id: String) {
        if customPresets.contains(where: { $0.id == id }) { deletePreset(id); return }
        guard EQPreset.allCases.contains(where: { $0.id == id }) else { return }
        let affectsCurrent = songBindings[selectedID] == id
        hiddenPresets.insert(id)
        songBindings = songBindings.filter { $0.value != id }
        if affectsCurrent { applySongBinding() }; save()
    }
    func restoreBuiltinModes() { hiddenPresets = []; save() }
    func profile(for id: String) -> SoundProfile? {
        if let preset = EQPreset.allCases.first(where: { $0.id == id }) {
            var value = SoundProfile.flat; value.gains = preset.gains
            if preset == .concert { value.ambience = .concert; value.mix = 18 }
            return value
        }
        return customPresets.first { $0.id == id }?.sound
    }
    func apply(_ preset: EQPreset) { applyPreset(id: preset.id) }
    func applyPreset(id: String) {
        guard let value = profile(for: id) else { return }
        unboundSound = nil
        setSound(value)
    }
    func resetEQ() { unboundSound = nil; setSound(.flat) }
    func adjustBand(_ index: Int, to value: Double) {
        guard eqEnabled, gains.indices.contains(index), value.isFinite else { return }
        let gain = (min(12, max(-12, value)) * 2).rounded() / 2
        guard gains[index] != gain else { return }
        if manualEQBaseline == nil { manualEQBaseline = sound }
        gains[index] = gain
        updateManualChanges()
    }
    private func clearManualEQChanges() { manualEQBaseline = nil; hasManualEQChanges = false }
    private func setSound(_ value: SoundProfile) {
        clearManualEQChanges()
        applying = true
        let p = value.sanitized
        gains = p.gains; eqEnabled = p.enabled; bassBoost = p.bass; ambience = p.ambience; ambienceMix = p.mix
        applying = false; syncAudio(); save()
    }
    func setSongProfilePolicy(_ enabled: Bool) { useSongProfiles = enabled; applySongBinding(); save() }
    func bindSong(to id: String) {
        if id.isEmpty { songBindings.removeValue(forKey: selectedID) }
        else if profile(for: id) != nil { songBindings[selectedID] = id }
        applySongBinding(); save()
    }
    private func applySongBinding() {
        guard eqEnabled else { return }
        if useSongProfiles, let id = songBindings[selectedID], let value = profile(for: id) {
            if unboundSound == nil { unboundSound = sound }
            setSound(value)
        } else if let base = unboundSound {
            unboundSound = nil; setSound(base)
        }
    }
    func editPreset(_ id: String? = nil) {
        presetError = nil
        editingPresetID = id; presetInput = customPresets.first { $0.id == id }?.name ?? ""
        showPresetEditor = true
    }
    @discardableResult func savePresetName() -> Bool {
        let name = presetInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 30 else { presetError = "模式名稱須為 1～30 個字。"; return false }
        guard !customPresets.contains(where: { $0.id != editingPresetID && $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }), !EQPreset.allCases.contains(where: { $0.rawValue == name }) else { presetError = "已有相同名稱，請換一個名稱。"; return false }
        if let id = editingPresetID, let index = customPresets.firstIndex(where: { $0.id == id }) { customPresets[index].name = name }
        else {
            guard customPresets.count < 20 else { presetError = "最多可儲存 20 組自訂模式。"; return false }
            customPresets.append(CustomPreset(id: "custom." + UUID().uuidString, name: name, sound: sound))
            clearManualEQChanges()
        }
        showPresetEditor = false; save(); return true
    }
    func updatePreset(_ id: String) {
        guard let index = customPresets.firstIndex(where: { $0.id == id }) else { return }
        customPresets[index].sound = sound
        clearManualEQChanges()
        if songBindings[selectedID] == id { applySongBinding() }
        save()
    }
    func deletePreset(_ id: String) {
        let affectsCurrent = songBindings[selectedID] == id
        customPresets.removeAll { $0.id == id }
        songBindings = songBindings.filter { $0.value != id }
        if affectsCurrent { applySongBinding() }; save()
    }
    private func syncAudio() {
        guard !applying else { return }
        audio.configure(gains: gains, enabled: eqEnabled, volume: volume)
        audio.configureEffects(bass: sound.bass, ambience: ambience, mix: sound.mix, enabled: eqEnabled)
    }
    func save() { guard !applying else { return }; if let data = settingsData { onSave?(data) } }
    private func installRemoteCommands() {
        #if os(iOS)
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in guard let self else { return }; if !self.isPlaying && self.playbackRequest == nil { self.start() } }
            return .success
        }
        center.pauseCommand.addTarget { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in guard let self else { return }; if self.isPlaying || self.playbackRequest != nil { self.togglePlayback() } }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in self?.togglePlayback() }; return .success
        }
        center.nextTrackCommand.addTarget { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in self?.next() }; return .success
        }
        center.previousTrackCommand.addTarget { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in self?.previous() }; return .success
        }
        center.changePlaybackPositionCommand.addTarget { @Sendable [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            Task { @MainActor [weak self] in self?.seek(to: position) }; return .success
        }
        #endif
    }
    private func updateNowPlaying() {
        guard hasPlaybackSession, !installingLibraryIndex,
              let track = tracks.first(where: { $0.id == selectedID }) else { return }
        let metadata = collection.metadata(for: track)
        nowPlaying.update(NowPlayingSnapshot(id: track.id, title: metadata.title, artist: metadata.artist,
            duration: track.duration, second: Int(currentTime), playing: isPlaying, artwork: metadata.artwork))
    }
    func refreshNowPlayingArtwork() { updateNowPlaying() }
    static func time(_ seconds: Double) -> String {
        let value = seconds.isFinite ? max(0, Int(min(seconds, Double(Int32.max)))) : 0
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}


/// Frequent render-clock ticks must never invalidate menu and sheet owners.
@MainActor final class PlaybackClock: ObservableObject {
    @Published var time = 0.0
}
