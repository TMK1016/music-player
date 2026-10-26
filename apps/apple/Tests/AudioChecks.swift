import Foundation
import AVFoundation
import Combine

@MainActor final class FakeAudioPlayer: AudioPlayback {
    var currentTime = 0.0
    var onCompletion: (() -> Void)?
    var onInterruption: ((String) -> Void)?
    var loadedURL: URL?
    var playing = false
    var appliedGains: [Double] = []
    var eqEnabled = true
    var appliedBass = 0.0
    var appliedAmbience: Ambience = .off
    func load(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { throw PlaybackError.missingFile }
        loadedURL = url; currentTime = 0
    }
    func play() throws { playing = true }
    func pause() { playing = false }
    func seek(to seconds: Double) { currentTime = seconds }
    func stop() { playing = false; currentTime = 0 }
    func configureEffects(bass: Double, ambience: Ambience, mix: Double, enabled: Bool) { appliedBass = bass; appliedAmbience = ambience }
    func configure(gains: [Double], enabled: Bool, volume: Double) { appliedGains = gains; eqEnabled = enabled }
}

@main struct AudioChecks {
    @MainActor static func main() async throws {
        // Reproduce the real engine notification's queue boundary without audio hardware.
        let notification = Notification.Name("MusicPlayer.background-engine-regression")
        let signal = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            var token: AnyCancellable?
            token = AudioNotificationBridge.observe(notification) {
                MainActor.assertIsolated()
                token?.cancel()
                continuation.resume(returning: true)
            }
            DispatchQueue.global().async { NotificationCenter.default.post(name: notification, object: nil) }
        }
        precondition(signal, "Background audio notification safely reaches MainActor")
        print("PASS: real notification bridge accepts a background callback and executes its handler on MainActor")
        let work = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true).appendingPathComponent("test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        let fixture = URL(fileURLWithPath: CommandLine.arguments[2])
        let source = work.appendingPathComponent("海岸測試.wav")
        let duplicate = work.appendingPathComponent("same-content.wav")
        try FileManager.default.copyItem(at: fixture, to: source)
        try FileManager.default.copyItem(at: fixture, to: duplicate)
        let corrupt = work.appendingPathComponent("corrupt.wav")
        try Data("not an audio file".utf8).write(to: corrupt)
        let root = work.appendingPathComponent("Library", isDirectory: true)
        let store = LibraryStore(root: root)
        let result = try await store.importFiles([source, duplicate, corrupt])
        precondition(result.added == 1 && result.duplicates == 1 && result.failures.count == 1, "Import/dedup/error accounting")
        precondition(result.tracks[0].title == "海岸測試" && result.tracks[0].channels == 2 && result.tracks[0].duration == 18, "Metadata matches decoded file")
        precondition(FileManager.default.fileExists(atPath: source.path), "Source is preserved")
        let reloaded = try await LibraryStore(root: root).load()
        precondition(reloaded == result.tracks, "Manifest round trip")
        // The library must remain playable without its original external file.
        try FileManager.default.removeItem(at: source)
        let copiedURL = root.appendingPathComponent(result.tracks[0].filename!)
        let copiedFile = try AVAudioFile(forReading: copiedURL)
        precondition(copiedFile.length == 18 * 44100, "Offline copy survives source removal")
        let damagedRoot = work.appendingPathComponent("Damaged")
        try FileManager.default.createDirectory(at: damagedRoot, withIntermediateDirectories: true)
        let damaged = Data("broken index".utf8)
        try damaged.write(to: damagedRoot.appendingPathComponent("library.json"))
        do { _ = try await LibraryStore(root: damagedRoot).importFiles([fixture]); preconditionFailure("Must refuse corrupt index") }
        catch {
            let preserved = try Data(contentsOf: damagedRoot.appendingPathComponent("library.json"))
            precondition(preserved == damaged, "Corrupt index is not overwritten")
        }

        // v0.7 collection and listening rules use an isolated library.
        let uiRoot = work.appendingPathComponent("Experience")
        let uiAudio = FakeAudioPlayer()
        let uiModel = PlayerModel(audio: uiAudio, libraryRoot: uiRoot, demoURL: fixture)
        await uiModel.loadLibrary()
        precondition(uiModel.songs(in: "liked").isEmpty && uiModel.songs(in: "unfamiliar").isEmpty, "Unrated excluded from both modes")
        precondition(RatingInteraction.value(at: -20, width: 220) == 1 && RatingInteraction.value(at: 500, width: 220) == 5, "Star drag clamps at both edges")
        precondition(RatingInteraction.value(at: 44, width: 220) == 1 && RatingInteraction.value(at: 45, width: 220) == 2 && RatingInteraction.value(at: 220, width: 220) == 5, "Star drag maps all five hit regions")
        precondition(RatingInteraction.value(at: .nan, width: 220) == 0 && RatingInteraction.value(at: 5, width: 0) == 0, "Invalid geometry never creates invalid rating")
        uiModel.setPlaybackMode("單曲重複")
        precondition(uiModel.repeatOne && !uiModel.repeatAll && !uiModel.shuffle, "Unified mode selects repeat-one exclusively")
        uiModel.setPlaybackMode("隨機播放")
        precondition(!uiModel.repeatOne && !uiModel.repeatAll && uiModel.shuffle, "Unified mode clears conflicting options")
        uiModel.setPlaybackMode("清單循環")
        precondition(!uiModel.repeatOne && uiModel.repeatAll && !uiModel.shuffle, "Unified loop mode is exclusive")
        uiModel.setPlaybackMode("順序播放")
        precondition(!uiModel.repeatOne && !uiModel.repeatAll && !uiModel.shuffle, "Sequential restores no-repeat state")
        uiModel.setRating(AudioTrack.demo.id, 3)
        precondition(uiModel.songs(in: "liked").count == 1 && uiModel.songs(in: "unfamiliar").count == 1, "Three stars belongs to both modes")
        precondition(uiModel.favorites.isEmpty, "Rating does not change favorites")
        uiModel.createPlaylist("Drive")
        let listID = uiModel.collection.playlists[0].id
        uiModel.addToPlaylist(AudioTrack.demo.id, listID); uiModel.addToPlaylist(AudioTrack.demo.id, listID)
        precondition(uiModel.songs(in: listID).count == 1, "Playlist insertion is unique")
        uiModel.removeFromPlaylist(AudioTrack.demo.id, listID)
        precondition(uiModel.tracks.count == 1 && uiModel.songs(in: listID).isEmpty, "Removing membership retains track")
        uiModel.editSong(.demo, title: "Renamed", artistName: "Artist")
        let artistID = uiModel.details(AudioTrack.demo.id).artistID!
        uiModel.updateArtist(artistID, name: "New Artist", avatar: nil)
        precondition(uiModel.artist(.demo) == "New Artist" && uiModel.title(.demo) == "Renamed", "Artist rename preserves song identity")
        uiModel.choose(.demo)
        let loadedBeforeUI = uiAudio.loadedURL
        uiModel.page = .player
        uiModel.adjustBand(0, to: 1.5)
        precondition(uiModel.isPlaying && uiAudio.playing && uiAudio.loadedURL == loadedBeforeUI && uiAudio.appliedGains[0] == 1.5, "In-player EQ reaches backend without stopping or reloading the track")
        uiModel.setRating(AudioTrack.demo.id, 5)
        precondition(uiModel.isPlaying && uiAudio.playing, "Rating while listening never interrupts playback")
        uiModel.setRating(AudioTrack.demo.id, 3)
        let clock = ProcessInfo.processInfo.systemUptime
        uiAudio.currentTime = 9; uiModel.pollPlayback(now: clock + 9)
        precondition(uiModel.playCount(AudioTrack.demo.id, monthly: false) == 0, "Exactly half is not counted")
        uiAudio.currentTime = 9.2; uiModel.pollPlayback(now: clock + 9.2)
        precondition(uiModel.playCount(AudioTrack.demo.id, monthly: false) == 1, "Strictly over half counts once")
        uiAudio.currentTime = 17; uiModel.pollPlayback(now: clock + 17)
        precondition(uiModel.playCount(AudioTrack.demo.id, monthly: false) == 1, "Same session never counts twice")
        uiModel.choose(.demo)
        let replayClock = ProcessInfo.processInfo.systemUptime
        uiAudio.currentTime = 10; uiModel.pollPlayback(now: replayClock + 10)
        precondition(uiModel.playCount(AudioTrack.demo.id, monthly: false) == 2, "Replay can count again")
        uiModel.choose(.demo); uiModel.seek(to: 15)
        let seekClock = ProcessInfo.processInfo.systemUptime
        uiAudio.currentTime = 16; uiModel.pollPlayback(now: seekClock + 1)
        precondition(uiModel.playCount(AudioTrack.demo.id, monthly: false) == 2, "Seeked-over duration is excluded")
        uiModel.scheduleSleep(songs: 1); uiModel.repeatOne = true
        uiAudio.onCompletion?()
        precondition(!uiModel.isPlaying && uiModel.sleepSongsRemaining == nil, "Song limit wins over repeat and pauses")
        uiModel.choose(.demo); uiModel.sleepDeadline = .distantPast; uiModel.pollPlayback()
        precondition(!uiModel.isPlaying && uiModel.sleepDeadline == nil, "Expired timer pauses")
        let uiReload = PlayerModel(audio: FakeAudioPlayer(), libraryRoot: uiRoot, demoURL: fixture)
        precondition(uiReload.rating(AudioTrack.demo.id) == 3 && uiReload.artist(.demo) == "New Artist" && uiReload.playCount(AudioTrack.demo.id, monthly: false) == 2, "Collection persistence round trip")
        await uiModel.importFiles([fixture])
        let importedUI = uiModel.tracks.first { !$0.isDemo }!
        uiModel.addToPlaylist(importedUI.id, listID)
        await uiModel.deleteAudioFile(importedUI)
        precondition(uiModel.tracks.count == 1 && uiModel.songs(in: listID).isEmpty && FileManager.default.fileExists(atPath: fixture.path), "Delete removes app copy and memberships, preserves external original")
        print("PASS: ratings, playlist uniqueness/removal, artist edits, half-duration/replay/seek counting, sleep limits, collection restore and file deletion")

        let audio = FakeAudioPlayer()
        var saved: Data?
        let model = PlayerModel(onSave: { saved = $0 }, audio: audio, libraryRoot: root, demoURL: fixture)
        precondition(!model.hasManualEQChanges, "Loading does not request a new mode")
        model.adjustBand(0, to: 3)
        precondition(model.hasManualEQChanges && !model.showPresetEditor, "Manual adjustment offers saving without interrupting")
        model.editPreset(); model.showPresetEditor = false
        precondition(model.hasManualEQChanges, "Cancel preserves unsaved adjustment")
        model.adjustBand(0, to: 0)
        precondition(!model.hasManualEQChanges, "Returning sliders to baseline dismisses prompt")
        model.adjustBand(0, to: 2)
        model.apply(.flat)
        precondition(!model.hasManualEQChanges, "Selecting a mode clears manual prompt")
        model.adjustBand(1, to: 2)
        model.editPreset(); model.presetInput = "Inline save check"
        precondition(model.savePresetName() && !model.hasManualEQChanges, "Saving current adjustment clears prompt")
        model.deletePreset(model.customPresets.last!.id)
        model.resetEQ()
        await model.loadLibrary()
        precondition(model.tracks.count == 2, "Library merges bundled demo and imports")
        model.choose(model.tracks[1])
        precondition(model.isPlaying && audio.playing && audio.loadedURL == copiedURL, "Choosing a track calls audio backend")
        model.progress = 0.5
        precondition(audio.currentTime == 9 && model.currentTime == 9, "Seek reaches backend")
        model.togglePlayback()
        precondition(!model.isPlaying && !audio.playing && model.currentTime == 9, "Pause preserves position")
        model.togglePlayback()
        precondition(model.isPlaying && audio.playing, "Resume")
        model.apply(.vocal)
        precondition(audio.appliedGains == EQPreset.vocal.gains, "EQ controls reach backend")
        model.eqEnabled = false
        precondition(!audio.eqEnabled, "Bypass reaches backend")
        model.toggleFavorite(model.track)
        model.volume = 0.43
        let restored = PlayerModel(savedData: saved, audio: FakeAudioPlayer(), libraryRoot: root, demoURL: fixture)
        await restored.loadLibrary()
        precondition(restored.favorites == model.favorites && restored.gains == model.gains && restored.volume == 0.43, "Settings and imported favorites persist")
        model.search = "海岸"
        precondition(model.filteredTracks.count == 1, "Search includes imported titles")
        model.search = "missing song"
        precondition(model.filteredTracks.isEmpty, "Empty result")
        model.search = ""
        model.choose(model.tracks.last!)
        audio.onCompletion?()
        precondition(!model.isPlaying && model.progress == 1, "Last track stops without repeat")
        model.repeatAll = true
        model.togglePlayback()
        audio.onCompletion?()
        precondition(model.track.id == AudioTrack.demo.id && model.isPlaying, "Repeat wraps at natural completion")
        audio.onInterruption?("test interruption")
        precondition(!model.isPlaying && model.message == "test interruption", "Interruptions update UI")
        model.resetEQ()
        precondition(model.gains == EQPreset.flat.gains, "EQ reset")
        let allThree = Array(repeating: 3.0, count: EQBands.count)
        let combinedGain = EQHeadroom.gain(gains: allThree)
        precondition(combinedGain > -15 && combinedGain < -6, "Combined response avoids sum-of-gains attenuation while retaining overlap allowance")
        precondition(EQHeadroom.gain(gains: [], bass: .nan, sampleRate: .nan).isFinite, "Malformed headroom inputs stay finite")
        precondition(EQHeadroom.gain(gains: allThree, sampleRate: 16000) > -15, "Unavailable upper bands do not add headroom")
        precondition(EQHeadroom.gain(gains: allThree, ambience: .hall, mix: 0) == combinedGain, "Zero wet mix does not reserve reverb headroom")
        print("PASS: combined-response headroom, input sanitization, low-rate and zero-mix handling")
        let invalid = Data(#"{"version":1,"gains":[99,-99,0,0,0,0,0,0,0,0],"eqEnabled":false,"volume":3,"favorites":[]}"#.utf8)
        let sanitized = PlayerModel(savedData: invalid, audio: FakeAudioPlayer(), libraryRoot: root)
        precondition(sanitized.gains == EQBands.migrate([99,-99,0,0,0,0,0,0,0,0]) && sanitized.gains.count == 7 && sanitized.volume == 1, "Legacy parameters are bounded before migration")
        precondition(EQBands.migrate(Array(repeating: 3, count: 10)) == Array(repeating: 3, count: 7), "Flat old control contour remains flat")
        let oldFrequencies = EQBands.legacyFrequencies.map { log2($0 / 32) }
        let migrated = EQBands.migrate(oldFrequencies)
        for (index, frequency) in EQBands.frequencies.enumerated() {
            precondition(abs(migrated[index] - log2(frequency / 32)) < 0.00001, "Migration interpolates on log-frequency axis")
        }
        let legacySettings: [String: Any] = ["version":2,"gains":Array(repeating: 2.0,count:10),"eqEnabled":true,"volume":0.37,"favorites":["favorite"],"customs":[["id":"custom.legacy","name":"舊模式","sound":["gains":Array(repeating:3.0,count:10),"enabled":true,"bass":2.0,"ambience":"關閉","mix":15.0]]],"bindings":[AudioTrack.demo.id:"custom.legacy"]]
        let legacyModel = PlayerModel(savedData: try JSONSerialization.data(withJSONObject: legacySettings), audio: FakeAudioPlayer())
        precondition(legacyModel.gains == Array(repeating:3,count:7) && legacyModel.customPresets[0].id == "custom.legacy" && legacyModel.customPresets[0].name == "舊模式" && legacyModel.songBindings[AudioTrack.demo.id] == "custom.legacy" && legacyModel.volume == 0.37 && legacyModel.favorites.contains("favorite"), "v2 custom mode and binding migrate without identity loss")
        let encoded = try JSONSerialization.jsonObject(with: legacyModel.settingsData!) as! [String: Any]
        precondition(encoded["version"] as? Int == 3, "Migrated settings write schema v3")
        legacyModel.removeMode(EQPreset.rock.id)
        precondition(!legacyModel.modeOptions.contains { $0.id == EQPreset.rock.id }, "Factory removal updates the shared mode list")
        let hiddenRestored = PlayerModel(savedData: legacyModel.settingsData, audio: FakeAudioPlayer())
        precondition(hiddenRestored.hiddenPresets.contains(EQPreset.rock.id), "Factory visibility persists")
        hiddenRestored.bindSong(to: EQPreset.vocal.id)
        hiddenRestored.removeMode(EQPreset.vocal.id)
        precondition(hiddenRestored.songBindings[hiddenRestored.selectedID] == nil, "Removing factory mode also clears song bindings")
        hiddenRestored.restoreBuiltinModes()
        precondition(hiddenRestored.modeOptions.contains { $0.id == EQPreset.rock.id }, "Removed factory modes can be restored")
        precondition(EQPreset.allCases.allSatisfy { $0.gains.count == 7 }, "Every builtin preset uses seven bands")
        print("PASS: seven-band presets, logarithmic v1/v2 migration, custom identity/binding retention, v3 persistence and shared mode list removal/restore")
        model.choose(model.tracks[0], autoplay: false)
        model.resetEQ(); model.bassBoost = 5; model.ambience = .hall; model.ambienceMix = 23
        precondition(audio.appliedBass == 5 && audio.appliedAmbience == .hall, "Effects reach backend")
        model.presetInput = "通勤"; precondition(model.savePresetName())
        let commute = model.customPresets[0].id
        model.resetEQ(); model.applyPreset(id: commute)
        precondition(model.bassBoost == 5 && model.ambience == .hall && model.ambienceMix == 23, "Custom preset captures all effects")
        model.editPreset(commute); model.presetInput = "早上通勤"; precondition(model.savePresetName())
        precondition(model.customPresets[0].id == commute, "Rename preserves binding identity")
        model.bassBoost = 4; model.updatePreset(commute)
        model.resetEQ(); model.applyPreset(id: commute)
        precondition(model.bassBoost == 4, "Overwrite stores current sound")
        model.resetEQ(); model.apply(.jazz)
        let global = model.sound
        model.bindSong(to: commute)
        precondition(model.bassBoost == 4, "Binding immediately applies")
        model.choose(model.tracks[1], autoplay: false)
        precondition(model.sound == global, "Unbound next track restores global sound")
        model.choose(model.tracks[0], autoplay: false)
        precondition(model.bassBoost == 4, "Returning to bound track applies automatically")
        let roundTrip = PlayerModel(savedData: model.settingsData, audio: FakeAudioPlayer(), libraryRoot: root)
        precondition(roundTrip.customPresets[0].name == "早上通勤" && roundTrip.bassBoost == 4 && roundTrip.songBindings[model.tracks[0].id] == commute, "v3 preset and binding restore")
        model.editPreset(); model.presetInput = "早上通勤"; precondition(!model.savePresetName(), "Reject duplicate names")
        model.presetInput = " "; precondition(!model.savePresetName(), "Reject blank names")
        for index in 1..<20 { model.editPreset(); model.presetInput = "模式 \(index)"; precondition(model.savePresetName()) }
        model.editPreset(); model.presetInput = "第21組"; precondition(!model.savePresetName() && model.customPresets.count == 20, "Enforce 20 custom modes")
        model.deletePreset(commute)
        precondition(model.customPresets.count == 19 && model.songBindings.isEmpty && model.sound == global, "Delete cleans bindings and restores general sound")
        model.choose(model.tracks[1], autoplay: false)
        model.bindSong(to: EQPreset.concert.id)
        precondition(model.ambience == .concert, "Factory presets also bind")
        model.bindSong(to: "")
        precondition(model.sound == global, "Unbind restores general sound")
        precondition(sanitized.customPresets.isEmpty && sanitized.bassBoost == 0, "v1 settings migrate with defaults")
        var oldPreferences = try JSONSerialization.jsonObject(with: model.settingsData!) as! [String: Any]
        oldPreferences["vehicle"] = ["name": "Legacy car", "seat": "Driver"]
        let cleaned = try PreferencesCleanup.removingVehicleData(JSONSerialization.data(withJSONObject: oldPreferences))
        let cleanedObject = try JSONSerialization.jsonObject(with: cleaned) as! [String: Any]
        precondition(cleanedObject["vehicle"] == nil && cleanedObject["gains"] != nil, "Vehicle data removed without losing EQ")
        let restoredClean = PlayerModel(savedData: cleaned, audio: FakeAudioPlayer())
        let rewritten = try JSONSerialization.jsonObject(with: restoredClean.settingsData!) as! [String: Any]
        precondition(rewritten["vehicle"] == nil, "Removed vehicle settings are never re-encoded")
        precondition(PlayerPage.destination(for: "vehicle") == nil, "Historical journal cannot navigate to retired page")
        print("PASS: retired vehicle preference cleanup, EQ preservation and removed destination")
        print("PASS: factory/custom sound profiles, bindings and settings migration")
        print("PASS: transactional import, deduplication, invalid audio, offline copy, manifest recovery, playback commands, seek, EOF/repeat, interruption, settings and EQ wiring")

        if !CommandLine.arguments.contains("--model-only") { print(try NativeEQChecks.run()) }
    }
}
