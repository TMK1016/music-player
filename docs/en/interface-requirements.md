# Interface request — complete English translation

Date: 2026-10-24.

“To answer your earlier question: I am currently using a Mac M2 with Xcode to develop and package the application. The intended use is for drivers to play music through my app. I also want speaker equalizer functionality to improve their driving experience. If the current functionality is sufficiently defined, please start by developing the software interface, using a technology-inspired blue color palette as the primary visual direction.”

## Interpretation and implementation scope

Confirmed: Apple Silicon M2 development machine, Xcode development and packaging, driver-oriented music playback with equalizer controls, blue visual direction, and an interface-first implementation.

Not yet confirmed: the final in-car playback device, CarPlay entitlement, vehicle/head-unit model, available independent channels, and source-download permissions. A Mac development machine does not by itself establish the production playback platform.

This iteration creates shared native SwiftUI interfaces with separate macOS and iOS build targets. It provides demo-state interactions and settings persistence. It does not implement audio decoding/output, Rust DSP, actual speaker calibration, downloads, iCloud access, or CarPlay. The source structure keeps the interface separate from the future Rust audio core.
