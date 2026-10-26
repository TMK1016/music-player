import AVFoundation
import Combine

@MainActor protocol AudioPlayback: AnyObject {
    var currentTime: Double { get }
    var onCompletion: (() -> Void)? { get set }
    var onInterruption: ((String) -> Void)? { get set }
    func load(_ url: URL) throws
    func play() throws
    func pause()
    func seek(to seconds: Double) throws
    func stop()
    func configure(gains: [Double], enabled: Bool, volume: Double)
    func configureEffects(bass: Double, ambience: Ambience, mix: Double, enabled: Bool)
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

@MainActor enum AudioGraph {
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
    private let equalizer = AVAudioUnitEQ(numberOfBands: EQBands.count)
    private let bassUnit = AVAudioUnitEQ(numberOfBands: 1)
    private let reverb = AVAudioUnitReverb()
    private var bass = 0.0
    private var ambience: Ambience = .off
    private var ambienceMix = 15.0
    private var file: AVAudioFile?
    private var segmentStart: AVAudioFramePosition = 0
    private var scheduled = false
    private var generation = 0
    private var gains = EQBands.flat
    private var enabled = true
    private var volume = 0.5
    private var observers: [AnyCancellable] = []
    private var needsReconnect = false
    var onCompletion: (() -> Void)?
    var onInterruption: ((String) -> Void)?

    init() {
        engine.attach(player)
        engine.attach(equalizer)
        engine.attach(bassUnit)
        engine.attach(reverb)
        NotificationCenter.default.publisher(for: .AVAudioEngineConfigurationChange, object: engine)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.file != nil else { return }
                    let position = self.currentTime
                    self.generation += 1
                    self.player.stop()
                    self.engine.stop()
                    self.segmentStart = AVAudioFramePosition(position * (self.file?.processingFormat.sampleRate ?? 44_100))
                    self.scheduled = false
                    self.needsReconnect = true
                    self.onInterruption?("音訊輸出已變更，播放已暫停。請按播放重新連接。")
                }
            }.store(in: &observers)
        #if os(iOS)
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                let began = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
                guard began else { return }
                Task { @MainActor [weak self] in self?.pause(); self?.onInterruption?("播放已被系統中斷，請在方便時重新播放。") }
            }.store(in: &observers)
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] notification in
                let disconnected = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
                guard disconnected else { return }
                Task { @MainActor [weak self] in self?.pause(); self?.onInterruption?("音訊裝置已中斷，播放已暫停。") }
            }.store(in: &observers)
        #endif
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
        configure(gains: gains, enabled: enabled, volume: volume)
    }
    private func reconnect() throws {
        guard let file else { return }
        engine.disconnectNodeOutput(player)
        engine.disconnectNodeOutput(equalizer)
        engine.disconnectNodeOutput(bassUnit)
        engine.disconnectNodeOutput(reverb)
        try AudioGraph.connect(engine, player, to: equalizer, format: file.processingFormat)
        try AudioGraph.connect(engine, equalizer, to: bassUnit, format: file.processingFormat)
        try AudioGraph.connect(engine, bassUnit, to: reverb, format: file.processingFormat)
        try AudioGraph.connect(engine, reverb, to: engine.mainMixerNode, format: file.processingFormat)
        engine.prepare()
        needsReconnect = false
    }
    func play() throws {
        guard file != nil else { throw PlaybackError.noTrack }
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        #endif
        if needsReconnect { try reconnect() }
        if !engine.isRunning { try engine.start() }
        if !scheduled { schedule() }
        try AudioGraph.play(player)
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
        player.scheduleSegment(file, startingFrame: segmentStart, frameCount: frames, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.scheduled = false
                self.segmentStart = file.length
                self.onCompletion?()
            }
        }
    }
    func stop() {
        generation += 1
        player.stop()
        engine.stop()
        equalizer.reset(); bassUnit.reset(); reverb.reset()
        scheduled = false
        segmentStart = 0
        file = nil
    }
    func configure(gains: [Double], enabled: Bool, volume: Double) {
        self.gains = gains; self.enabled = enabled; self.volume = volume
        EqualizerSettings.apply(to: equalizer, gains: gains, enabled: enabled, sampleRate: file?.processingFormat.sampleRate ?? 44_100)
        applyEffects()
        engine.mainMixerNode.outputVolume = Float(min(1, max(0, volume.isFinite ? volume : 0.5)))
    }
    func configureEffects(bass: Double, ambience: Ambience, mix: Double, enabled: Bool) {
        self.bass = bass.isFinite ? min(9, max(0, bass)) : 0
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
        SoundEffectSettings.apply(equalizer: equalizer, bassUnit: bassUnit, reverb: reverb, gains: gains, bass: bass, ambience: ambience, mix: ambienceMix, enabled: enabled, sampleRate: file?.processingFormat.sampleRate ?? 44100)
    }

}


@MainActor enum SoundEffectSettings {
    static func apply(equalizer: AVAudioUnitEQ, bassUnit: AVAudioUnitEQ, reverb: AVAudioUnitReverb, gains: [Double], bass: Double, ambience: Ambience, mix: Double, enabled: Bool, sampleRate: Double = 44100) {
        let amount = bass.isFinite ? min(9, max(0, bass)) : 0
        let band = bassUnit.bands[0]
        band.filterType = .lowShelf; band.frequency = 90; band.gain = Float(amount)
        band.bypass = !enabled || amount == 0
        equalizer.globalGain = EQHeadroom.gain(gains: gains, bass: amount, sampleRate: sampleRate, ambience: ambience, mix: mix)
        reverb.wetDryMix = enabled && ambience != .off ? Float(mix.isFinite ? min(35, max(0, mix)) : 0) : 0
        reverb.bypass = !enabled || ambience == .off
    }
}
