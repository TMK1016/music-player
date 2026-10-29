import AVFoundation
import AudioToolbox

/// Apple peak limiter followed by one explicit 1 dB reconstruction reserve.
/// No positive pre-gain, hard clipper, loudness normalizer or song scan. The
/// stereo-link behavior is checked with asymmetric PCM, not inferred from UI.
final class PeakControl {
    static let reserveDB: Float = -1
    let limiter = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
        componentType: kAudioUnitType_Effect, componentSubType: kAudioUnitSubType_PeakLimiter,
        componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0))
    let reserve = AVAudioMixerNode()
    init() {
        // SDK documented ranges: attack 1–30 ms, decay 1–60 ms. These are
        // engineering choices, not promises about internal detector topology.
        AudioUnitSetParameter(limiter.audioUnit, kLimiterParam_AttackTime, kAudioUnitScope_Global, 0, 0.003, 0)
        AudioUnitSetParameter(limiter.audioUnit, kLimiterParam_DecayTime, kAudioUnitScope_Global, 0, 0.060, 0)
        AudioUnitSetParameter(limiter.audioUnit, kLimiterParam_PreGain, kAudioUnitScope_Global, 0, 0, 0)
        setEnabled(true)
    }
    func attach(to engine: AVAudioEngine) { engine.attach(limiter); engine.attach(reserve) }
    func connect(_ engine: AVAudioEngine, from source: AVAudioNode, to destination: AVAudioNode, format: AVAudioFormat) throws {
        try AudioGraph.connect(engine, source, to: limiter, format: format)
        try AudioGraph.connect(engine, limiter, to: reserve, format: format)
        try AudioGraph.connect(engine, reserve, to: destination, format: format)
    }
    func disconnect(from engine: AVAudioEngine) { engine.disconnectNodeOutput(limiter); engine.disconnectNodeOutput(reserve) }
    func setEnabled(_ enabled: Bool) {
        limiter.bypass = !enabled
        reserve.outputVolume = enabled ? pow(10, Self.reserveDB / 20) : 1
    }
    func reset() { limiter.reset(); reserve.reset() }
}
