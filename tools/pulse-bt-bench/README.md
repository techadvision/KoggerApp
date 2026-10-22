# Bottom-track bench (analysis aid, not app code)

Replays a Pulse `.plog` through a line-by-line Python port of `BottomTrackProcessor::bottomTrackProcessing`
and of the realtime pass schedule in `DataProcessor` (each pass: `indexFrom = prevTo - W`, `indexTo = currTo`, one new
epoch per pass, the dataset running ~2 epochs ahead of the chart counter). Built 18 Oct 2026 for the depth-source analysis
(`docs/pulse-ui/pulse-depth-source-analysis.md`).

- `plog.py` - KP1 frame reader (Fletcher-checked) and chart assembler (`ID_CHART` v0/v1, lost fragments zero-filled
  or, with `FILL_FROM_PREVIOUS`, filled from the previous ping as blue's black-stripe processor does). The `.plog` also
  holds the rangefinder: the device's depth arrives as NMEA `$SDDBT` over the same link and the logger writes every
  frame (3837 sentences in a five-minute red log) - `rfsim.py` and the DBT checks of analysis 11.3 read them with a regex
  over the raw file, position-mapped to the epochs.
- `bt.py` - the port (presets 0/1/2, window, vertical gap, min/max distance, gain slope, threshold; int32 semantics) and
  `realtime()`, which returns the final value per epoch and every publish in order (what the readout and NMEA see).
- `run2d.py <plog> "<preset,W,vgap,min,max,gain,thr>" <out.npz> [fill]` - runs it and saves values, ranges and the
  per-epoch peak score, mean and 95th percentile of the trace.
- `feat.py` - per-epoch echo contrast (the trace peak within 0.1 m of the found bottom / the trace median past 0.4 m).
- `gates.py <plog> <npz> <pulse.log>` - the shore checks: labels every epoch shore / water from the app log of the same
  run (the clock comes from the `LINK:` ping rates, see the docstring) and reports, per gate of the plan (A geometry,
  B echo contrast, the outlier filter), the shore epochs removed and the water epochs lost. The constants mirror
  `src/depth_gates.h`; change them together. Re-run on both 18 Oct recordings after every change to a gate.
- `sweep.py <plog> <preset> <min> <max> [fill] [pings/s]` - window / gain slope / vertical gap sweep of the bottom track on one
  recording, judged raw and after the gates against a +-3 s rolling median of the baseline run (analysis section 7.4).
- `outlier.py` - a port of `depthgates::OutlierFilter` (P5b); gates.py runs it over the gated epochs and reports what it held
  in the water and on the two real slopes of the 18 Oct run (which must stay at zero).
- `match.py` - checks the bench against the app's own `BT: epoch` lines in `pulse.log` (finds the epoch offset).
- `rfsim.py <app log> <date> [HH:MM:SS-HH:MM:SS] [blue]` - the rangefinder's steady reading and its veto (analysis 11.3),
  replayed from an app log's `SHALLOW:` lines; `blue` switches the blue's own-zone floor.
- `benchb.py <bench dir> <testlogs dir>` - gate B's floor tried at several values on every blue recording (11.6).
- `benchp11.py <bench dir>` - P11, the second echo, with and without, on every recording (11.7).
- `sweep3a.py` / `sweep3b.py <sets...>` - the blue's parameter sets on ANDY through the whole pipeline (11.8).
- `benchmax.py` - Max's 22 Oct quarry-lake run: the glide and the rangefinder's quality (section 12).

`gates.py` and `outlier.py` carry the C++ rules as they stand (gates A and B, P11 `second_echo_half`, the outlier filter
with the witness veto and the return rule); `depth_gates.h` is the original, these are the mirrors - change them together.

Profiles: red/black `(1,5,0.04,0.25,50,2,0)`; blue `(2,15,0.0,0.25,35,0.5,0)` since 22 Oct 2026 (was `(2,5,0.04,0.25,35,2,0)`),
with `fill`. The `.npz` files of past runs live outside the repo (`~/bench/` on Olav's Mac).

Validation, 18 Oct logs: the bench reproduces the app's logged per-epoch bottom track to 0.01 m for 81 of 93 red lines
and 112 of 144 blue lines - including the noise-driven shore values, which are the hardest to match. The misses sit where
the app's epoch numbering drifts against the file (a few epochs the file does not have).
