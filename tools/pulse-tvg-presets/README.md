# pulse-tvg-presets - the offline strips behind the side scan TVG levels (22 Oct 2026)

A Python port of `EchogramSideScanTvg::apply` (`src/scene2d/echogram_sidescan_tvg.*`) and of the side scan
AGC (`Epoch::Echogram::updateCompesated`), run on blue `.plog` recordings, to compare gain laws before any app
code. It reuses the bench's `.plog` reader (`tools/pulse-bt-bench/plog.py`). Display is the app's level mapping
(`Plot2DEchogram::updateColors`) at intensity 10 (levels 0..80), in grey.

    # 1. extract the side scan pings of a recording (numpy cache, outside the repo)
    python3 extract.py ../pulse-bt-bench testlogs/depth-source/SS_pulse_log_2026.10.19_17.20.15.plog /tmp/tvg/2026.10.19_17.20.15
    # 2. a full-log overview (TVG as shipped), to pick windows
    python3 overview.py /tmp/tvg/2026.10.19_17.20.15 testlogs/tvg-presets
    # 3. the comparison strips: near and far crop per window, one column per gain law
    python3 run_strips2.py testlogs/tvg-presets /tmp/tvg
    # 4. the numbers: bottom brightness by range bin, far/near ratio, saturation per law
    python3 profile.py /tmp/tvg
    # 5. detail boost: bottom high-pass std and water-column speckle at beta 0.9 / 1.2 / 1.5
    python3 boost.py /tmp/tvg

`run_strips2.py` and `profile.py` name the recordings they expect in the cache directory (ANDY, 18 Oct, 19 Oct,
Max 22 Oct). The findings are in `docs/pulse-ui/pulse-ui-strategy.md`, "22 Oct 2026 (evening) - the 2.0 run-up".
The side scan noise-floor step is not ported (0 at release).

## The 2D noise floor - P5 of the motor-noise plan (7 Nov 2026)

`tvg2d.py` is the port of `EchogramTvg::apply` (`src/scene2d/echogram_tvg.*`) with P5's floor step, `extract2d.py`
the 2D extraction (one channel, plus the bench's bottom track so the strips can be judged against the bottom), and
`strips2d.py` the strips: the same pings at strength 0 / 0.3 / 0.6 / 1.0, depth axis in metres, the bottom track in red,
with the display mean 0.5-1.5 m under the bottom, in the water column and at the bottom peak per window.

    python3 extract2d.py ../pulse-bt-bench "testlogs/Andy_noise/2D_pulse_log_2026.11.03_11.42.57.plog" ~/tvg2d/andy1142 fill
    python3 strips2d.py ~/tvg2d testlogs/tvg2d-strips

What the strips showed (Andy's three 3 Nov plogs, Olav's 6 Nov 16:06): the motor-noise fog in the water column goes
cleanly (display 0.17-0.25 -> 0.03-0.05 at strength 1); the band under the bottom only thins (0.6 -> 0.35) because
most of it is a bottom tail of ~70 raw that is there with the motor off too; the bottom peak loses some level on
the black at strength 1 (0.82 -> 0.71), none on the built-in red. The estimator is the 30th percentile, not the
plan's median, for the reason in `tvg2d.py`'s docstring. The C++ was checked against this port on five of Andy's
pings (identical output).

P5b, after Olav's device check of the first cut (screenshots in `testlogs/Screenshots of noise floor`): Andy's boat
needed strength 1 to clear its fog and that took the bottom from red to green; the subtraction now has a soft knee
(full at the floor, none from 3 x floor up). At strength 1 on Andy's 11:28 the water column reads 0.04 against 0.03
without the knee, the bottom peak 0.90 against 0.67, and the band under the bottom keeps 0.49 against 0.34
(`*_knee.png` in the strips folder shows plain against knee side by side).
