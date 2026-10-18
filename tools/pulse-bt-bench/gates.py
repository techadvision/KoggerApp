"""Shore checks: the gates of the depth-source plan (P3 gate A, P4 gate B, P5b outlier filter) tried on a replayed
recording, scored against hand labels (shore / water) taken from the app log of the same run.

    python3 gates.py <plog> <npz from run2d.py> <pulse.log> [--labels NAME]

Prints per gate: shore epochs removed (%), water epochs lost (%) - the two numbers the analysis quotes
(docs/pulse-ui/pulse-depth-source-analysis.md 1.6). The constants here mirror the C++ (src/dataset.cpp, "DEPTH GATES");
change them together."""
import os, re, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import feat

# --- the constants, as in Dataset (keep in step with src/dataset.cpp) -------------------------------------------
GATE_A_FRACTION = 0.75      # bottom track beyond this fraction of the reachable end is "no bottom"
GATE_A_RANGE_FRACTION = 0.9 # reachable end = min(maxDistance, this x the trace range)
GATE_B_CONTRAST = 1.5       # peak at the bottom / trace median (past 0.4 m) below this is "no echo"
GATE_B_WINDOW = 9           # majority over this many epochs (the epoch and the ones before it)
GATE_B_SKIP_M = 0.4         # ringdown skipped before the median
GATE_B_PEAK_M = 0.1         # half-width of the peak search around the found bottom

# --- labels: shore stretches per recording, from the app log (BT: last 10 s - rangefinder at its ringdown, bottom
#     track at the far end). Water = everything else, with a margin on both sides of each shore stretch left out.
SHORE = {
    '2D_pulse_log_2026.10.18_15.00.29.plog': ('15:00:29', '15:07:05', [('15:00:00', '15:00:50'), ('15:04:01', '15:04:38'), ('15:06:22', '15:08:00')]),
    'SS_pulse_log_2026.10.18_15.10.27.plog': ('15:10:27', '15:21:05', [('15:10:00', '15:10:52'), ('15:20:23', '15:22:00')]),
}
MARGIN_S = 5.0   # the clock is good to ~1-2 s; the transitions themselves are not scored

def hms(t):
    h, m, s = t.split(':'); return int(h) * 3600 + int(m) * 60 + float(s)

def epoch_times(log, n_epochs, t0, t1):
    """Seconds-of-day per file epoch. The .plog carries no clock, so the clock comes from the app log: every
    `LINK:` line gives the measured ping rate of its 10 s window; the pings accumulated from the recording's start
    time (its file name) are the file's epoch counter. Checked against the red's range changes (`DYNAMIC: plan`
    lines against the range steps in the file): within ~1 s over the whole recording."""
    w = []   # (window end, pings/s)
    for l in open(log, errors='replace'):
        m = re.search(r'^\S+ (\d\d:\d\d:\d\d\.\d+) .*LINK: \S+ \| .*\| ([\d.]+) pings/s', l)
        if m and t0 <= m.group(1)[:8] <= t1:
            w.append((hms(m.group(1)), float(m.group(2))))
    start = hms(t0); ts = [start]; ks = [0.0]
    for t_end, rate in w:
        if t_end <= ts[-1]: continue
        ks.append(ks[-1] + rate * (t_end - ts[-1])); ts.append(t_end)
    ks.append(ks[-1] + w[-1][1] * 60); ts.append(ts[-1] + 60)   # run on at the last rate
    return np.interp(np.arange(n_epochs), ks, ts), (len(w), round(float(np.interp(n_epochs, ks, ts)) - start, 1))

def labels(name, times):
    start, end, stretches = SHORE[name]
    shore = np.zeros(len(times), bool); water = np.ones(len(times), bool)
    for a, b in stretches:
        a, b = hms(a), hms(b)
        shore |= (times >= a) & (times <= b)
        water &= ~((times >= a - MARGIN_S) & (times <= b + MARGIN_S))
    return shore, water

# --- the gates --------------------------------------------------------------------------------------------------
def gate_a(bt, rng, maxd):
    reach = np.minimum(maxd, GATE_A_RANGE_FRACTION * rng)
    return np.isfinite(bt) & (bt > GATE_A_FRACTION * reach)

def gate_b(contrast, bt):
    """Per epoch: the majority of the last GATE_B_WINDOW epochs (this one included) that have a bottom show no echo."""
    weak = np.isfinite(bt) & ~(contrast >= GATE_B_CONTRAST)   # NaN contrast with a bottom counts as weak
    has = np.isfinite(bt)
    out = np.zeros(len(bt), bool)
    for i in range(len(bt)):
        a = max(0, i - GATE_B_WINDOW + 1)
        n = has[a:i + 1].sum(); w = weak[a:i + 1].sum()
        out[i] = has[i] and n > 0 and 2 * w > n
    return out

def report(name, bt, shore, water, gates):
    print(f'{name}: {len(bt)} epochs, shore {shore.sum()} (with bottom {np.isfinite(bt[shore]).sum()}), water {water.sum()} (with bottom {np.isfinite(bt[water]).sum()})')
    hs = shore & np.isfinite(bt); hw = water & np.isfinite(bt)
    for label, g in gates.items():
        print(f'  {label:<10} shore removed {100 * g[hs].mean():5.1f}%   water lost {100 * g[hw].mean():5.2f}%  ({g[hw].sum()} epochs)')

def main():
    plog_path, npz_path, log_path = sys.argv[1:4]
    name = os.path.basename(plog_path)
    z = np.load(npz_path); bt = z['final']; rng = z['rng']
    maxd = 35.0 if name.startswith('SS_') else 50.0
    start, end = SHORE[name][:2]
    times, info = epoch_times(log_path, len(bt), start, end)
    print(f'clock from {info[0]} LINK lines; file {start} + {info[1]} s, {len(bt)} epochs')
    shore, water = labels(name, times)
    f, r, con, lvl = feat.feats(plog_path, npz_path)
    A = gate_a(bt, rng, maxd); B = gate_b(con, bt)
    report(name, bt, shore, water, {'A': A, 'B': B, 'A or B': A | B})
    np.savez(npz_path.replace('.npz', '_gates.npz'), A=A, B=B, times=times, shore=shore, water=water, con=con)

if __name__ == '__main__':
    main()
