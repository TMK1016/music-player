import AVFoundation
import Combine
import OSLog

@MainActor protocol AudioPlayback: AnyObject {
    var currentTime: Double { get }
    var onCompletion: (() -> Void)? { get set }
    var onInterruption: ((String) -> Void)? { get set }
    var onProcessingGain: ((Float?) -> Void)? { get set }
    var onBassAnalysisStatus: ((String?) -> Void)? { get set }
    func prepareForPlayback(completion: @escaping @MainActor @Sendable (Result<Void, Error>) -> Void)
    func load(_ url: URL) throws
    func play() throws
    func pause()
    func seek(to seconds: Double) throws
    func stop()
    func configure(gains: [Double], enabled: Bool, volume: Double)
    func configureEffects(bass: Double, ambience: Ambience, mix: Double, enabled: Bool)
}

// Backends without a hardware session can complete immediately (including macOS).
extension AudioPlayback {
    var onProcessingGain: ((Float?) -> Void)? { get { nil } set {} }
    var onBassAnalysisStatus: ((String?) -> Void)? { get { nil } set {} }
    func prepareForPlayback(completion: @escaping @MainActor @Sendable (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
}

/// All mutable preparation state belongs to this queue. No sync wait on MainActor.
/// Completion is explicitly actor-isolated; the worker never touches UI/engine state.
final class SerialAudioPreparation: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.orca.player.session", qos: .userInitiated)
    private let operation: @Sendable (Bool) throws -> Void
    private var configured = false // queue-confined, set only after successful preparation
    init(operation: @escaping @Sendable (Bool) throws -> Void) { self.operation = operation }
    func prepare(completion: @escaping @MainActor @Sendable (Result<Void, Error>) -> Void) {
        queue.async { [self] in
            let result = Result { try operation(configured) }
            if case .success = result { configured = true }
            Task { @MainActor in completion(result) }
        }
    }
}

enum PlaybackError: LocalizedError {
    case invalidAudio, noTrack, missingFile
    var errorDescription: String? {
        switch self {
        case .invalidAudio: "此音檔無法播放。目前支援系統可解碼的單聲道或雙聲道音檔。"
        case .noTrack: "請先選擇或匯入音樂。"
        case .missingFile: "音檔不存在，請重新匯入。"
        }
    }
}

enum EqualizerSettings {
    static let frequencies = EQBands.frequencies.map(Float.init)
    /// Estimated combined response + 3 dB margin, retained during bypass for A/B.
    static func headroom(gains: [Double]) -> Float {
        EQHeadroom.gain(gains: gains)
    }
    static func apply(to equalizer: AVAudioUnitEQ, gains: [Double], enabled: Bool, sampleRate: Double) {
        equalizer.globalGain = EQHeadroom.gain(gains: gains, sampleRate: sampleRate)
        for (index, band) in equalizer.bands.enumerated() {
            let frequency = frequencies[index]
            band.filterType = .parametric
            band.frequency = min(frequency, Float(sampleRate * 0.45))
            band.bandwidth = Float(EQBands.bandwidth)
            let gain = index < gains.count && gains[index].isFinite ? gains[index] : 0
            band.gain = Float(min(12, max(-12, gain)))
            band.bypass = !enabled || Double(frequency) >= sampleRate * 0.45
        }
    }
}

enum AudioGraph {
    static func connect(_ engine: AVAudioEngine, _ source: AVAudioNode, to destination: AVAudioNode, format: AVAudioFormat) throws {
        if #available(macOS 27.0, iOS 27.0, *) { try engine.connectNode(source, to: destination, format: format) }
        else { engine.connect(source, to: destination, format: format) }
    }
    static func play(_ player: AVAudioPlayerNode) throws {
        if #available(macOS 27.0, iOS 27.0, *) { try player.playAudio() }
        else { player.play() }
    }
}

/// Apple owns the real-time render loop. File I/O and UI updates stay off that loop.
@MainActor final class NativeAudioPlayer: AudioPlayback {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let inputMixer = AVAudioMixerNode()
    private let equalizer = AVAudioUnitEQ(numberOfBands: EQBands.count)
    private let bassUnit = AVAudioUnitEQ(numberOfBands: 1)
    private let reverb = AVAudioUnitReverb()
    private let peakControl = PeakControl()
    private var bass = 0.0
    private var ambience: Ambience = .off
    private var ambienceMix = 15.0
    private var file: AVAudioFile?
    private var gainRampTask: Task<Void, Never>?
    var onProcessingGain: ((Float?) -> Void)?
    var onBassAnalysisStatus: ((String?) -> Void)?

    private var segmentStart: AVAudioFramePosition = 0
    private var scheduled = false
    private var generation = 0
    private var gains = EQBands.flat
    private var enabled = true
    private var volume = 0.5
    private var observers: [AnyCancellable] = []
    private var needsReconnect = false
    private var parametersApplied = false
    private var preparedEQRate: Double?
    #if os(iOS)
    private let sessionPreparation = SerialAudioPreparation { configured in
        dispatchPrecondition(condition: .notOnQueue(.main))
        let session = AVAudioSession.sharedInstance()
        if session.category != .playback { try session.setCategory(.playback, mode: .default) }
        if !configured {
            do { try session.setPreferredIOBufferDuration(0.046) }
            catch { Logger(subsystem: "com.orca.player", category: "audio-continuity").notice("Preferred I/O duration unavailable; retaining system value") }
        }
        // Re-activate on each explicit start, including after a system interruption.
        try session.setActive(true)
    }
    #endif
    private let logger = Logger(subsystem: "com.orca.player", category: "audio-continuity")
    var onCompletion: (() -> Void)?
    var onInterruption: ((String) -> Void)?

    init() {
        engine.attach(player)
        engine.attach(inputMixer)
        engine.attach(equalizer)
        engine.attach(bassUnit)
        engine.attach(reverb)
        peakControl.attach(to: engine)
        AudioNotificationBridge.observe(.AVAudioEngineConfigurationChange, object: engine) { [weak self] in
            guard let self, self.file != nil, !self.engine.isRunning else { return }
            self.logger.notice("Engine configuration changed while stopped; pausing for explicit reconnect")
            let position = self.currentTime
            self.generation += 1
            self.player.stop()
            self.engine.stop()
            self.segmentStart = AVAudioFramePosition(position * (self.file?.processingFormat.sampleRate ?? 44_100))
            self.scheduled = false
            self.needsReconnect = true
            self.onInterruption?("音訊輸出已變更，播放已暫停。請按播放重新連接。")
        }.store(in: &observers)
        #if os(iOS)
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { @Sendable [weak self] notification in
                let began = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
                guard began else { return }
                Task { @MainActor [weak self] in self?.pause(); self?.onInterruption?("播放已被系統中斷，請在方便時重新播放。") }
            }.store(in: &observers)
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { @Sendable [weak self] notification in
                let disconnected = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
                guard disconnected else { return }
                Task { @MainActor [weak self] in self?.pause(); self?.onInterruption?("音訊裝置已中斷，播放已暫停。") }
            }.store(in: &observers)
        #endif
    }
    // Read-only native parameter evidence for integration checks; no render tap.
    var processingParameters: (gains: [Float], bass: Float, preamp: Float) {
        (equalizer.bands.map(\.gain), bassUnit.bands[0].gain, equalizer.globalGain)
    }
    var currentTime: Double {
        guard let file else { return 0 }
        var frames = segmentStart
        if scheduled, let render = player.lastRenderTime, let time = player.playerTime(forNodeTime: render) {
            frames += max(0, time.sampleTime)
        }
        return min(Double(file.length) / file.processingFormat.sampleRate, Double(frames) / file.processingFormat.sampleRate)
    }
    func load(_ url: URL) throws {
        stop()
        guard FileManager.default.fileExists(atPath: url.path) else { throw PlaybackError.missingFile }
        let candidate = try AVAudioFile(forReading: url)
        guard candidate.length > 0, candidate.length <= Int64(UInt32.max), (1...2).contains(candidate.processingFormat.channelCount), candidate.processingFormat.sampleRate > 0 else { throw PlaybackError.invalidAudio }
        file = candidate
        try reconnect()
        parametersApplied = false; preparedEQRate = nil
        configure(gains: gains, enabled: enabled, volume: volume)
    }
    private func reconnect() throws {
        guard let file else { return }
        engine.disconnectNodeOutput(player)
        engine.disconnectNodeOutput(inputMixer)
        engine.disconnectNodeOutput(equalizer)
        engine.disconnectNodeOutput(bassUnit)
        engine.disconnectNodeOutput(reverb)
        peakControl.disconnect(from: engine)
        // Normalize mono to dual mono before effects: Apple's reverb/limiter
        // graph must not inherit an unsupported mono bus configuration.
        let processing = AVAudioFormat(standardFormatWithSampleRate: file.processingFormat.sampleRate, channels: 2)!
        try AudioGraph.connect(engine, player, to: inputMixer, format: file.processingFormat)
        try AudioGraph.connect(engine, inputMixer, to: equalizer, format: processing)
        try AudioGraph.connect(engine, equalizer, to: bassUnit, format: processing)
        try AudioGraph.connect(engine, bassUnit, to: reverb, format: processing)
        try peakControl.connect(engine, from: reverb, to: engine.mainMixerNode, format: processing)
        engine.prepare()
        needsReconnect = false
    }
    func play() throws {
        guard file != nil else { throw PlaybackError.noTrack }
        if needsReconnect { try reconnect() }
        if !engine.isRunning { try engine.start() }
        if !scheduled { schedule() }
        try AudioGraph.play(player)
    }
    func prepareForPlayback(completion: @escaping @MainActor @Sendable (Result<Void, Error>) -> Void) {
        #if os(iOS)
        sessionPreparation.prepare(completion: completion)
        #else
        completion(.success(()))
        #endif
    }
    func pause() { player.pause() }
    func seek(to seconds: Double) throws {
        guard let file, seconds.isFinite else { return }
        let resume = player.isPlaying
        generation += 1
        player.stop()
        segmentStart = min(file.length - 1, max(0, AVAudioFramePosition(seconds * file.processingFormat.sampleRate)))
        scheduled = false
        schedule()
        if resume { try AudioGraph.play(player) }
    }
    private func schedule() {
        guard let file else { return }
        let token = generation
        let frames = AVAudioFrameCount(file.length - segmentStart)
        scheduled = true
        player.scheduleSegment(file, startingFrame: segmentStart, frameCount: frames, at: nil, completionCallbackType: .dataPlayedBack) { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.scheduled = false
                self.segmentStart = file.length
                self.onCompletion?()
            }
        }
    }
    func stop() {
        gainRampTask?.cancel(); gainRampTask = nil
        generation += 1
        player.stop()
        engine.stop()
        inputMixer.reset(); equalizer.reset(); bassUnit.reset(); reverb.reset(); peakControl.reset()
        scheduled = false
        segmentStart = 0
        file = nil
    }
    func configure(gains: [Double], enabled: Bool, volume: Double) {
        let rate = file?.processingFormat.sampleRate ?? 44_100
        let soundChanged = !parametersApplied || self.gains != gains || self.enabled != enabled || preparedEQRate != rate
        let safeVolume = min(1, max(0, volume.isFinite ? volume : 0.5))
        guard soundChanged || self.volume != safeVolume else { return }
        self.gains = gains; self.enabled = enabled; self.volume = safeVolume
        if soundChanged {
            if preparedEQRate != rate {
                // Topology parameters only change with format, never with a page,
                // volume update or opening an editor.
                EqualizerSettings.apply(to: equalizer, gains: gains, enabled: enabled, sampleRate: rate)
                preparedEQRate = rate
            }
            applyEffects()
        }
        if engine.mainMixerNode.outputVolume != Float(safeVolume) { engine.mainMixerNode.outputVolume = Float(safeVolume) }
        parametersApplied = true
    }
    func configureEffects(bass: Double, ambience: Ambience, mix: Double, enabled: Bool) {
        let nextBass = bass.isFinite ? min(9, max(0, bass)) : 0
        let nextMix = mix.isFinite ? min(35, max(0, mix)) : 15
        guard self.bass != nextBass || self.ambience != ambience || self.ambienceMix != nextMix || self.enabled != enabled else { return }
        self.bass = nextBass
        if self.ambience != ambience {
            switch ambience {
            case .off: break
            case .room: reverb.loadFactoryPreset(.smallRoom)
            case .concert: reverb.loadFactoryPreset(.largeHall)
            case .hall: reverb.loadFactoryPreset(.mediumHall)
            case .spacious: reverb.loadFactoryPreset(.largeChamber)
            }
            self.ambience = ambience
        }
        self.ambienceMix = mix.isFinite ? min(35, max(0, mix)) : 15
        self.enabled = enabled
        applyEffects()
    }
    private func applyEffects() {
        gainRampTask?.cancel()
        let start = equalizer.bands.map(\.gain)
        let startBass = bassUnit.bands[0].gain
        // One gain policy: unity EQ preamp, then dynamic peak control. No
        // content-analysis gain or static summed/headroom attenuation is added.
        SoundEffectSettings.apply(equalizer: equalizer, bassUnit: bassUnit, reverb: reverb, gains: gains, bass: parametersApplied && enabled ? Double(startBass) : bass, ambience: ambience, mix: ambienceMix, enabled: enabled, sampleRate: file?.processingFormat.sampleRate ?? 44100, preamp: 0)
        peakControl.setEnabled(enabled)
        for (index, band) in equalizer.bands.enumerated() {
            band.bypass = !enabled || Double(EqualizerSettings.frequencies[index]) >= (file?.processingFormat.sampleRate ?? 44100) * 0.45
        }
        // Keep a zero-gain shelf in circuit, avoiding a bypass transition during
        // a bass ramp. New files/disabled master use immediate deterministic state.
        bassUnit.bands[0].bypass = !enabled
        onProcessingGain?(0)
        onBassAnalysisStatus?(enabled ? "即時峰值控制" : nil)
        let targets = gains.map { Float($0.isFinite ? min(12, max(-12, $0)) : 0) }
        guard parametersApplied, enabled else {
            for (i, band) in equalizer.bands.enumerated() { band.gain = i < targets.count ? targets[i] : 0 }
            return
        }
        bassUnit.bands[0].gain = startBass
        let targetBass = Float(bass)
        // Bounded control work only; Apple owns rendering. Latest edit cancels
        // the previous ramp and begins at its actual intermediate values.
        gainRampTask = Task { [weak self] in
            for step in 1...16 {
                do { try await Task.sleep(for: .milliseconds(5)) } catch { return }
                guard let self else { return }
                let fraction = Float(step) / 16
                for (i, band) in self.equalizer.bands.enumerated() {
                    let target = i < targets.count ? targets[i] : 0
                    band.gain = start[i] + (target - start[i]) * fraction
                }
                self.bassUnit.bands[0].gain = startBass + (targetBass - startBass) * fraction
            }
        }
    }

}


enum SoundEffectSettings {
    static func apply(equalizer: AVAudioUnitEQ, bassUnit: AVAudioUnitEQ, reverb: AVAudioUnitReverb, gains: [Double], bass: Double, ambience: Ambience, mix: Double, enabled: Bool, sampleRate: Double = 44100, preamp: Float? = nil) {
        let amount = bass.isFinite ? min(9, max(0, bass)) : 0
        let band = bassUnit.bands[0]
        if band.filterType != .lowShelf { band.filterType = .lowShelf }
        if band.frequency != 90 { band.frequency = 90 }
        if band.gain != Float(amount) { band.gain = Float(amount) }
        let bypassBass = !enabled || amount == 0
        if band.bypass != bypassBass { band.bypass = bypassBass }
        let headroom = preamp ?? EQHeadroom.gain(gains: gains, bass: amount, sampleRate: sampleRate, ambience: ambience, mix: mix)
        if equalizer.globalGain != headroom { equalizer.globalGain = headroom }
        let wet = enabled && ambience != .off ? Float(mix.isFinite ? min(35, max(0, mix)) : 0) : 0
        if reverb.wetDryMix != wet { reverb.wetDryMix = wet }
        let bypassReverb = !enabled || ambience == .off
        if reverb.bypass != bypassReverb { reverb.bypass = bypassReverb }
    }
}

/// Notifications may arrive on AVAudioEngine's serial queue. The subscriber must
/// be nonisolated; only the action is scheduled onto the main actor.
enum AudioNotificationBridge {
    nonisolated static func observe(_ name: Notification.Name, object: AnyObject? = nil,
                                   action: @escaping @MainActor @Sendable () -> Void) -> AnyCancellable {
        NotificationCenter.default.publisher(for: name, object: object)
            .sink { @Sendable _ in
                Task { @MainActor in action() }
            }
    }
}
