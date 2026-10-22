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
The noise-floor step is not ported (0 at release).
