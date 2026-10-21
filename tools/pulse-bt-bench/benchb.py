"""Gate B's floor (GATE_B_FROM_FRACTION) tried at several values on the blue recordings.

    python3 benchb.py <bench dir with the npz files> <testlogs dir>

Per recording and floor: what B removes of the FALSE bottoms and what it costs of the GOOD ones. Good / false is
judged against a +-3 s rolling median of the run itself (sweep.py's reference: |bt - ref| <= max(0.5 m, 30%)),
restricted to the water where labels exist (gates.SHORE); for the 21 Oct stationary file everything over 1 m is
false (the water was 15-60 cm). Also printed: where the good bottoms sit as a fraction of the reach (the 99th
percentile), which is the floor a real bottom could reach."""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import feat, gates, sweep

bench, logs = sys.argv[1], sys.argv[2]
RUNS = [  # plog, npz, app log (None = unlabelled), maxDistance
    ('SS_pulse_log_ANDY_2026.10.03_11.16.09.plog', 'andy.npz', None, 35.0),
    ('SS_pulse_log_2026.10.18_15.10.27.plog', 'blue.npz', 'pulse_181026.log', 35.0),
    ('SS_pulse_log_2026.10.19_17.20.15.plog', 'blue19.npz', 'pulse app log 19.10.2026.log', 35.0),
    ('SS_pulse_log_2026.10.21_18.22.01.plog', 'blue21.npz', None, 35.0),
]
FLOORS = (0.5, 0.45, 0.4, 0.35, 0.3)
for plog_name, npz, log, maxd in RUNS:
    plog_path = os.path.join(logs, plog_name); npz_path = os.path.join(bench, npz)
    z = np.load(npz_path); bt = z['final']; rng = z['rng']
    f, r, con, lvl = feat.feats(plog_path, npz_path)
    reach = np.minimum(maxd, gates.GATE_A_RANGE_FRACTION * rng)
    frac = bt / reach
    if log:
        start, end = gates.SHORE[plog_name][:2]
        times, _ = gates.epoch_times(os.path.join(logs, log), len(bt), start, end)
        shore, water = gates.labels(plog_name, times)
    else:
        shore = np.zeros(len(bt), bool); water = np.ones(len(bt), bool)
    fin = np.isfinite(bt)
    if plog_name.startswith('SS_pulse_log_2026.10.21'):
        good = fin & (bt < 1.0); false = fin & (bt >= 1.0)
    else:
        ref = sweep.rolling_median(bt, 42)
        off = np.abs(bt - ref) > np.maximum(0.5, 0.3 * ref)
        good = fin & water & ~off; false = fin & water & off
    A = gates.gate_a(bt, rng, maxd)
    print(f'{plog_name}: {len(bt)} epochs; water good {good.sum()}, false {false.sum()}, shore {(shore & fin).sum()}; '
          f'good bottoms at {np.nanpercentile(frac[good], 50):.2f} (median) / {np.nanpercentile(frac[good], 99):.2f} (99th) of the reach; '
          f'gate A alone removes {100 * A[false].mean() if false.any() else 0:.1f}% of the false')
    print(f'  {"floor":>5} | {"false removed":>13} | {"good dashed":>11} | {"shore removed":>13}')
    for fl in FLOORS:
        gates.GATE_B_FROM_FRACTION = fl
        B = gates.gate_b(con, bt, rng, maxd)
        AB = A | B
        print(f'  {fl:>5} | {100 * AB[false].mean() if false.any() else 0:>12.1f}% | {100 * AB[good].mean() if good.any() else 0:>10.2f}% | '
              f'{100 * AB[shore & fin].mean() if (shore & fin).any() else 0:>12.1f}%')
    gates.GATE_B_FROM_FRACTION = 0.5
