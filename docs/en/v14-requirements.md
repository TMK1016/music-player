# V14 — bass enhancement and seven-band EQ

Authorized one-time deferred task. Do not implement before 2026-10-30 02:00 Asia/Taipei. Read the actual current time first; pause the identically named automation once started without interrupting this run. Start verified at 2026-10-29 18:00:51 UTC (= 2026-10-30 02:00:51 Taipei). Automation `4f95f8f2-7332-4456-8eb2-5f85b3bbf277` was verified disabled.

## Complete original V14 note translation

1. Bass enhancement still reduces volume considerably. Please use another approach. Other software I have used progressively increases the sensation of bass without changing the main volume. It may make the speakers distort, but at least the effect is obvious; the current implementation still does not feel like bass enhancement. Based on reference materials, combine the advantages of different methods to achieve the expected effect.
2. EQ modes and bass enhancement must work simultaneously, for example Rock EQ with bass level 3. Both effects should stack.
3. Find and implement verifiable improvements to the equalizer, for example signal analysis/interpretation or response adjustments.
4. Execute these three requirements only at 2 a.m. because the usage allowance is nearly exhausted. Update my connected phone when results are available.

## Complete execution instructions translated from the authorized task

Work in `/Users/yuanzhitang/Orca`, project `projects/music-player`. Read TMK準則.md, project AGENTS.md, README, user notes, planning records, V13-A implementation and native audio reports first. Baseline is 0.20.0/build30, commit `4b40b3555869d60be6f4ac984c62c96ca4fb344c`; the iPhone library has 1,230 tracks. Preserve compatibility identifiers, private library, modes and other features.

The goal is main volume close to the original, with clearly increasing bass as the independent control rises. Do not describe forced clipping as sound-quality improvement. Changing an EQ mode must not unnecessarily reset independent bass. Audit seven-band EQ signal handling, filter response, parameter updates and gain management; implement improvements supported by evidence.

First reproduce/measure the actual Plan A conditions. Determine whether analysis completes, whether peak constraints cause attenuation, and whether modes/song bindings overwrite bass. Do not merely retune static headroom, or compare against a bypass with the same attenuation and call that improvement. Other strategies are now authorized: evaluate low-frequency dynamics, moderate harmonics and necessary stereo-linked peak limiting, selecting a reasonable combination. Check official/primary sources, mark engineering assumptions, and avoid stacking multiple attenuation policies. Retain seven bands. There is no external DSP or driver feedback; do not restore vehicle settings.

Use the existing PM skill and necessary engineering/audio verification workflows. Preserve complete English requirements and communicate in Traditional Chinese. Complete implementation, settings compatibility and native PCM verification. Accept actual bass lift, midrange/overall loudness, peaks/distortion, rapid controls, track switching/background playback, Rock + bass3 and bass retention across modes. Distinguish test audio from in-car listening; do not promise zero distortion and identical loudness for every song. Performance analysis must never block playback rendering or the main thread.

Update issue tracking, external interactive flowchart, development journal and PM records. Execute necessary tests and both Apple platform builds. Update the connected iPhone in place, verify version/build, Running and retained library. Ask for user action only upon an actual obstruction such as a locked phone; do not delete the app. Update the friend source package, commit locally and attempt push. Claim synchronization only after checking the remote commit; retain an offline bundle if blocked.

Report actual changes, measurements, phone version and backup status in Traditional Chinese. Do not stop at advice/planning, execute early, or open an unauthorized new project.

## Acceptance and engineering assumptions

- V14-01 / EQ-01 / QA-01: compare true unity original, enabled bass0, and bass3/6/9 at 44.1/48/96 kHz; log 40 Hz, 1 kHz, gated K-weighted loudness, oversampled peak estimate, harmonic distortion and render duration. Dense bass and sparse high peaks must be separate cases.
- V14-02 / PROFILE-01: Rock+bass3 physically stacks; factory/custom selection, song binding/restoration and saved settings retain global bass. Explicit master-off/reset still restores Original by the existing V9 policy. Keep legacy stored profile bass snapshots decodable.
- V14-03 / EQ-01: retain validated 7-band response, fixed centers/width and rate-aware bypass; smooth gains and independent shelf over approximately 80 ms, cancel obsolete ramps. No full-song analysis in production playback.
- V14-04 / IOS-01 / QA-02 / RELEASE-01: builds, phone installation/Running/library, background declaration and actual-device limitations reported individually; external flow/journal/PM/source package/backup verified.
- Assumptions: a 90 Hz shelf plus transient peak control can make bass clearer without permanent whole-song attenuation on ordinary mixed material. Dense bass-dominant material will still invoke limiting and may lower mids. No loudspeaker response measurement supports a universal perceptual guarantee. Adding harmonics may help bandwidth-limited speakers but introduces coloration and intermodulation; defer unless justified by measured benefit. Apple limiter internals are opaque; verify stereo behavior empirically. A 1 dB post-limiter reserve is an engineering reconstruction allowance, not certified true-peak compliance.
