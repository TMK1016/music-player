# V13 — Plan A implementation authorization

The user confirms the equalizer already has seven bands and authorizes trying Plan A. The reported bass enhancement currently has no useful audible effect and reduces the overall volume. The immediate success criterion is to fix that behavior and increase perceived bass. Preserve the seven-band EQ, implement the previously proposed content-measured gain management for the separate bass control, validate actual audio output, and update the connected iPhone after completion.

Do not implement Plan B compression/limiting or Plan C harmonic generation. Preserve compatibility identifiers, library, presets, per-song bindings and existing bass values. The separate bass amount remains 0–9 dB; seven refers to EQ frequency bands. This is an Apple native backend implementation, not a Rust rewrite. Distinguish measured synthetic PCM results from subjective in-car verification and disclose analysis warm-up and peak-constrained cases.
