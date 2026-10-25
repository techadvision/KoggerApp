# Wave-compensation offline bench (analysis aids, not app code)

- `plog.py` - parses a Pulse `.plog` into KP1 frames (Fletcher-checked), MAVLink v1/v2 frames and NMEA sentences, in file order.
- `bt.py` - a line-by-line Python port of `BottomTrackProcessor::bottomTrackProcessing` (presets 0/1/2, window, vertical gap, min/max, gain slope, threshold) for one pass over a list of traces.

Used for the v3 validation in `../wave-compensation-code-review.md` (section 6) on `SS_pulse_log_2026.01.14_Titan.plog`.
To match the app, fill lost chart fragments from the previous ping before running `bt.py` (the black-stripe processor, Blue forward steps = 1); a zero fill overstates bottom-track outliers about tenfold.
