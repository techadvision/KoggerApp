# Bottom-track bench (analysis aid, not app code)

Replays a Pulse `.plog` through a line-by-line Python port of `BottomTrackProcessor::bottomTrackProcessing`
and of the realtime pass schedule in `DataProcessor` (each pass: `indexFrom = prevTo - W`, `indexTo = currTo`, one new
epoch per pass, the dataset running ~2 epochs ahead of the chart counter). Built 18 Oct 2026 for the depth-source analysis
(`docs/pulse-ui/pulse-depth-source-analysis.md`).

- `plog.py` - KP1 frame reader (Fletcher-checked) and chart assembler (`ID_CHART` v0/v1, lost fragments zero-filled
  or, with `FILL_FROM_PREVIOUS`, filled from the previous ping as blue's black-stripe processor does). The `.plog` holds
  no rangefinder: the device's depth arrives as NMEA `DBT`, which the logger does not record.
- `bt.py` - the port (presets 0/1/2, window, vertical gap, min/max distance, gain slope, threshold; int32 semantics) and
  `realtime()`, which returns the final value per epoch and every publish in order (what the readout and NMEA see).
- `run2d.py <plog> "<preset,W,vgap,min,max,gain,thr>" <out.npz> [fill]` - runs it and saves values, ranges and the
  per-epoch peak score, mean and 95th percentile of the trace.
- `feat.py` - per-epoch echo contrast (the trace peak within 0.1 m of the found bottom / the trace median past 0.4 m).
- `gates.py <plog> <npz> <pulse.log>` - the shore checks: labels every epoch shore / water from the app log of the same
  run (the clock comes from the `LINK:` ping rates, see the docstring) and reports, per gate of the plan (A geometry,
  B echo contrast, the outlier filter), the shore epochs removed and the water epochs lost. The constants mirror
  `src/depth_gates.h`; change them together. Re-run on both 18 Oct recordings after every change to a gate.
- `outlier.py` - a port of `depthgates::OutlierFilter` (P5b); gates.py runs it over the gated epochs and reports what it held
  in the water and on the two real slopes of the 18 Oct run (which must stay at zero).
- `match.py` - checks the bench against the app's own `BT: epoch` lines in `pulse.log` (finds the epoch offset).

Profiles: red/black `(1,5,0.04,0.25,50,2,0)`, blue `(2,5,0.04,0.25,35,2,0)` with `fill`.

Validation, 18 Oct logs: the bench reproduces the app's logged per-epoch bottom track to 0.01 m for 81 of 93 red lines
and 112 of 144 blue lines - including the noise-driven shore values, which are the hardest to match. The misses sit where
the app's epoch numbering drifts against the file (a few epochs the file does not have).
