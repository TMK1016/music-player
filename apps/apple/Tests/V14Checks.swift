import AVFoundation
import Foundation
import AppKit

@MainActor enum V14Checks {
    struct Output {
        let samples: [[Float]]
        let loudness: Double
        let peak: Double
        let seconds: Double
        let maxRenderMS: Double
        let p99RenderMS: Double
    }
    static func render(rate: Double, bass: Double, gains: [Double] = EQBands.flat, enabled: Bool = true, kind: Int = 0, ambience: Ambience = .off, mix: Double = 0) throws -> Output {
        FileHandle.standardError.write(Data("V14 render rate=\(rate) bass=\(bass) kind=\(kind) enabled=\(enabled)\n".utf8))
        let clock = Date.timeIntervalSinceReferenceDate
        let engine = AVAudioEngine(), player = AVAudioPlayerNode(), inputMixer = AVAudioMixerNode()
        let eq = AVAudioUnitEQ(numberOfBands: 7), low = AVAudioUnitEQ(numberOfBands: 1), reverb = AVAudioUnitReverb(), control = PeakControl()
        reverb.loadFactoryPreset(.smallRoom)
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
        let sourceFormat = AVAudioFormat(standardFormatWithSampleRate: rate, channels: kind == 5 ? 1 : 2)!
        let count = Int(rate * 4), channels = 2
        let input = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(count))!
        input.frameLength = AVAudioFrameCount(count)
        for c in 0..<Int(sourceFormat.channelCount) { for n in 0..<count {
            let t = Double(n)/rate
            let fade = min(1, Double(min(n,count-1-n))/256)
            let pulse = (t >= 2 && t < 2.2) ? 0.9*pow(sin(.pi*(t-2)/0.2),2) : 0
            let value: Double
            switch kind {
            case 1: value = 0.35*sin(2 * .pi * 40*t) + 0.55*sin(2 * .pi * 1000*t) + 0.02*sin(2 * .pi * 4000*t)
            case 2: value = pulse*sin(2 * .pi * 40*t) + 0.12*sin(2 * .pi * 1000*t)
            case 3: value = (c == 0 ? pulse*sin(2 * .pi * 40*t) : 0) + 0.12*sin(2 * .pi * 1000*t)
            case 7: value = 0.7*sin(2 * .pi * 40*t)
            case 4: value = 0.15*sin(2 * .pi * 40*t)
            case 6: value = 0
            default: value = 0.05*sin(2 * .pi * 40*t) + 0.12*sin(2 * .pi * 1000*t) + 0.02*sin(2 * .pi * 4000*t)
            }
            input.floatChannelData![c][n] = Float(value * fade)
        } }
        engine.attach(player); engine.attach(inputMixer); engine.attach(eq); engine.attach(low); engine.attach(reverb); control.attach(to: engine)
        try AudioGraph.connect(engine, player, to: inputMixer, format: sourceFormat)
        try AudioGraph.connect(engine, inputMixer, to: eq, format: format)
        try AudioGraph.connect(engine, eq, to: low, format: format)
        try AudioGraph.connect(engine, low, to: reverb, format: format)
        try control.connect(engine, from: reverb, to: engine.mainMixerNode, format: format)
        EqualizerSettings.apply(to: eq, gains: gains, enabled: enabled, sampleRate: rate)
        SoundEffectSettings.apply(equalizer: eq, bassUnit: low, reverb: reverb, gains: gains, bass: bass, ambience: ambience, mix: mix, enabled: enabled, sampleRate: rate, preamp: 0)
        control.setEnabled(enabled)
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 1024)
        player.scheduleBuffer(input)
        try engine.start(); try AudioGraph.play(player)
        defer { player.stop(); engine.stop() }
        let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        var samples = Array(repeating: [Float](), count: channels)
        var meter = AudioLevelMeter(rate: rate, channels: channels)
        let peaks = try AudioTruePeakMeter(format: format, capacity: 1024)
        var renderTimes = [Double]()
        var retries = 0
        while engine.manualRenderingSampleTime < Int64(count + Int(rate * (ambience == .off ? 0.1 : 4))) {
            let renderStart = Date.timeIntervalSinceReferenceDate
            let status = try engine.renderOffline(1024, to: output)
            renderTimes.append((Date.timeIntervalSinceReferenceDate - renderStart)*1000)
            guard status == .success else {
                retries += 1
                try BassPlanChecks.require(status != .error && retries < 32, "V14 offline render progress")
                continue
            }
            retries = 0
            try meter.consume(output); try peaks.consume(output)
            for c in 0..<channels { samples[c].append(contentsOf: UnsafeBufferPointer(start: output.floatChannelData![c], count: Int(output.frameLength))) }
        }
        try peaks.finish()
        try BassPlanChecks.require(samples.joined().allSatisfy { $0.isFinite }, "Finite native output")
        renderTimes.sort()
        return Output(samples: samples, loudness: meter.loudness ?? -999, peak: peaks.decibels, seconds: Date.timeIntervalSinceReferenceDate - clock, maxRenderMS: renderTimes.last ?? 0, p99RenderMS: renderTimes[Int(Double(renderTimes.count-1)*0.99)])
    }
    static func amplitude(_ samples: [Float], rate: Double, hz: Double, start: Double = 1, duration: Double = 1) -> Double {
        var re = 0.0, im = 0.0
        let first = Int(rate*start), count = Int(rate*duration)
        for n in first..<(first+count) {
            let phase = 2 * Double.pi * hz * Double(n)/rate
            re += Double(samples[n])*cos(phase); im += Double(samples[n])*sin(phase)
        }
        return 2*hypot(re, im)/Double(count)
    }
    static func db(_ ratio: Double) -> Double { 20*log10(max(1e-15,ratio)) }
    static func run() async throws -> String {
        var rows = ["rate,kind,bass,lowLiftVsUnityDB,midVsUnityDB,loudnessVsUnityLU,estimatedTPDB,renderSeconds,maxRenderMS,p99RenderMS"]
        for rate in [44100.0, 48000, 96000] {
            let dry = try render(rate: rate, bass: 0, enabled: false)
            var previous = -Double.infinity
            for bass in [0.0, 3, 6, 9] {
                let wet = try render(rate: rate, bass: bass)
                let low = db(amplitude(wet.samples[0], rate: rate, hz: 40)/amplitude(dry.samples[0], rate: rate, hz: 40))
                let mid = db(amplitude(wet.samples[0], rate: rate, hz: 1000)/amplitude(dry.samples[0], rate: rate, hz: 1000))
                try BassPlanChecks.require(low > previous && mid > -1.2 && abs(mid) < 1.2, "V14 monotonic absolute bass lift / main-volume retention")
                if bass >= 3 { try BassPlanChecks.require(low > bass*0.7-1, "V14 audible-range bass increase against true unity original") }
                try BassPlanChecks.require(wet.peak < 0, "V14 estimated output peak")
                rows.append("\(rate),moderate,\(bass),\(low),\(mid),\(wet.loudness-dry.loudness),\(wet.peak),\(wet.seconds),\(wet.maxRenderMS),\(wet.p99RenderMS)")
                previous = low
            }
        }
        let rate = 48000.0
        for kind in [1,2] {
            let dry = try render(rate: rate, bass: 0, enabled: false, kind: kind)
            for bass in [3.0,6,9] {
                let wet = try render(rate: rate, bass: bass, kind: kind)
                try BassPlanChecks.require(wet.peak <= 0, "Dense / transient peak handling")
                let mid = db(amplitude(wet.samples[0], rate: rate, hz: 1000)/amplitude(dry.samples[0], rate: rate, hz: 1000))
                let low = db(amplitude(wet.samples[0], rate: rate, hz: 40, start: kind == 2 ? 2 : 1, duration: kind == 2 ? 0.2 : 1)/max(1e-12,amplitude(dry.samples[0], rate: rate, hz: 40, start: kind == 2 ? 2 : 1, duration: kind == 2 ? 0.2 : 1)))
                rows.append("\(rate),\(kind == 1 ? "dense" : "pulse"),\(bass),\(low),\(mid),\(wet.loudness-dry.loudness),\(wet.peak),\(wet.seconds),\(wet.maxRenderMS),\(wet.p99RenderMS)")
            }
        }
        let rock = try render(rate: rate, bass: 3, gains: EQPreset.rock.gains)
        let rockDry = try render(rate: rate, bass: 0, gains: EQPreset.rock.gains)
        let rockDelta = db(amplitude(rock.samples[0],rate:rate,hz:40)/amplitude(rockDry.samples[0],rate:rate,hz:40))
        try BassPlanChecks.require(rockDelta > 2, "Rock plus bass 3 physically stacks")
        let asym = try render(rate: rate, bass: 9, kind: 3)
        let left = amplitude(asym.samples[0],rate:rate,hz:1000,start:2.05,duration:0.1)
        let right = amplitude(asym.samples[1],rate:rate,hz:1000,start:2.05,duration:0.1)
        let linkDifference = db(left/right)
        try BassPlanChecks.require(abs(linkDifference) < 0.5, "Asymmetric bass peak uses linked attenuation, preserving center probe")
        let tone = try render(rate: rate, bass: 9, kind: 4)
        let fundamental = amplitude(tone.samples[0],rate:rate,hz:40)
        var harmonics = 0.0
        for h in 2...20 { harmonics += pow(amplitude(tone.samples[0],rate:rate,hz:40*Double(h)),2) }
        let thd = 100*sqrt(harmonics)/fundamental
        try BassPlanChecks.require(thd < 0.1, "Unconstrained bass does not add unwanted harmonics")
        for gains in [[12.0,12,12,12,12,12,12], [12,-12,12,-12,12,-12,12]] {
            let stress = try render(rate:rate,bass:9,gains:gains,kind:1,ambience:.room,mix:35)
            try BassPlanChecks.require(stress.peak < 0, "Extreme EQ/bass/reverb finite bounded output")
        }
        let mono = try render(rate:16000,bass:9,kind:5)
        try BassPlanChecks.require(abs(db(amplitude(mono.samples[0],rate:16000,hz:1000)/0.12)+1) < 0.3, "Mono normalization preserves center amplitude")
        let limitedTone = try render(rate:rate,bass:9,kind:7)
        let limitedFundamental = amplitude(limitedTone.samples[0],rate:rate,hz:40)
        var limitedHarmonics = 0.0
        for h in 2...20 { limitedHarmonics += pow(amplitude(limitedTone.samples[0],rate:rate,hz:40*Double(h)),2) }
        let limitedTHD = 100*sqrt(limitedHarmonics)/limitedFundamental
        try BassPlanChecks.require(limitedTone.peak < 0, "Overloaded low tone remains peak controlled")
        let silence = try render(rate:rate,bass:9,kind:6)
        try BassPlanChecks.require(silence.samples.joined().allSatisfy { abs($0) < 1e-12 }, "Silence stays silent")
        // Production backend: no scan wait, no old result can overwrite a rapid
        // parameter sequence; volume updates keep the same policy.
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".wav")
        try BassPlanChecks.writeFixture(root,rate:rate)
        defer { try? FileManager.default.removeItem(at:root) }
        FileHandle.standardError.write(Data("V14 production rapid sequence\n".utf8))
        let native = NativeAudioPlayer()
        var gain: Float?, note: String?
        native.onProcessingGain = { gain = $0 }; native.onBassAnalysisStatus = { note = $0 }
        try native.load(root)
        for n in 0..<60 {
            native.configure(gains:n%2 == 0 ? EQPreset.rock.gains : EQBands.flat,enabled:true,volume:0.4)
            native.configureEffects(bass:Double(n%10),ambience:.off,mix:0,enabled:true)
            if n%10 == 0 { try native.seek(to:0.5); try native.load(root) }
        }
        native.configure(gains:EQPreset.rock.gains,enabled:true,volume:0.4)
        native.configureEffects(bass:3,ambience:.off,mix:0,enabled:true)
        try await Task.sleep(for:.milliseconds(150))
        try BassPlanChecks.require(gain == 0 && note == "即時峰值控制", "Rapid controls / file switches keep unity policy without asynchronous analysis overwrite")
        let state = native.processingParameters
        try BassPlanChecks.require(state.gains == EQPreset.rock.gains.map(Float.init) && state.bass == 3 && state.preamp == 0, "Actual native parameters settle to latest rock+bass3")
        // Synthetic fixture only, muted at the final application mixer. Exercise
        // real device rendering while this verifier is hidden, without playback
        // of user media or adding anything to a library.
        native.configure(gains:EQPreset.rock.gains,enabled:true,volume:0)
        try native.play()
        NSApplication.shared.hide(nil)
        try await Task.sleep(for:.milliseconds(500))
        try BassPlanChecks.require(native.currentTime > 0.25, "Muted real rendering progresses while verifier is hidden")
        for n in 0..<40 {
            native.configure(gains:n%2 == 0 ? EQPreset.rock.gains : EQPreset.vocal.gains,enabled:true,volume:0)
            native.configureEffects(bass:Double(n%10),ambience:.off,mix:0,enabled:true)
            try await Task.sleep(for:.milliseconds(5))
        }
        let before = native.currentTime
        try await Task.sleep(for:.milliseconds(200))
        try BassPlanChecks.require(native.currentTime > before, "Rapid live EQ/bass edits do not stop rendering")
        native.pause()
        let paused = native.currentTime
        try await Task.sleep(for:.milliseconds(100))
        try BassPlanChecks.require(abs(native.currentTime-paused) < 0.03, "Pause remains stable")
        try native.load(root)
        try native.play()
        try await Task.sleep(for:.milliseconds(200))
        try BassPlanChecks.require(native.currentTime > 0.05, "File reload reconnects and plays")
        var completed = 0
        native.onCompletion = { completed += 1 }
        try native.seek(to:7.7)
        try await Task.sleep(for:.milliseconds(700))
        try BassPlanChecks.require(completed == 1, "Seek and natural completion remain valid")
        native.stop()
        let report = "PASS: V14 production peak-control path; unity original reference, 3 rates, monotonic bass, dense/transient peaks, rock+bass3, asymmetric stereo, THD, silence, mono16k, extreme EQ/reverb, rapid parameters/seek/load, muted real rendering while hidden and natural completion.\nRock bass3 lift=\(rockDelta)dB; asymmetric center probe L/R delta=\(linkDifference)dB; 40Hz THD(2...20)=\(thd)%; overloaded tone THD=\(limitedTHD)% / estimated peak=\(limitedTone.peak)dB\n" + rows.joined(separator:"\n")
        return report
    }
}
