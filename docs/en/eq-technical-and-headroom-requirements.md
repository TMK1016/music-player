# EQ technical section and incremental volume improvement

2026-10-24 — Full translation of the current request:

“First, add a section about this issue to the interactive version so I can understand the details of how the equalizer processes audio. This will be part of the project's technical documentation. Then optimize the behavior in response to the issue I raised, explaining the implementation details and the reasons for the choices. You may list several possible solutions, but implement one at a time, starting with the one you consider best.”

Context: the user reports an excessive drop in playback volume when adjusting EQ. The earlier question requested an introduction to EQ, an explanation of Orca's implementation, and a comparison with other software's volume-handling methods.

Selected first increment: replace the sum-of-positive-slider-gains attenuation rule with an estimate of the combined filter frequency response, validated against Apple native PCM rendering. Keep a 3 dB margin and a separate conservative reserve for audible reverb. Do not represent this increment as loudness matching, a limiter, true-peak protection, or a universal clipping guarantee. Present those as separate later options. Keep the previously removed distance/delay UI removed.
