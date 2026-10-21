"""Shore checks: the gates of the depth-source plan (P3 gate A, P4 gate B, P5b outlier filter) tried on a replayed
recording, scored against hand labels (shore / water) taken from the app log of the same run.

    python3 gates.py <plog> <npz from run2d.py> <pulse.log> [--labels NAME]

Prints per gate: shore epochs removed (%), water epochs lost (%) - the two numbers the analysis quotes
(docs/pulse-ui/pulse-depth-source-analysis.md 1.6). The constants here mirror the C++ (src/dataset.cpp, "DEPTH GATES");
change them together."""
import os, re, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import feat, outlier

# --- the constants, as in Dataset (keep in step with src/dataset.cpp) -------------------------------------------
GATE_A_FRACTION = 0.75      # bottom track beyond this fraction of the reachable end is "no bottom"
GATE_A_RANGE_FRACTION = 0.9 # reachable end = min(maxDistance, this x the trace range)
GATE_B_CONTRAST = 1.5       # peak at the bottom / trace median (past 0.4 m) below this is "no echo"
GATE_B_FROM_FRACTION = 0.5  # B judges only a bottom beyond this fraction of the reachable end
GATE_B_WINDOW = 9           # majority over this many epochs (the epoch and the ones before it)
GATE_B_SKIP_M = 0.4         # ringdown skipped before the median
GATE_B_PEAK_M = 0.1         # half-width of the peak search around the found bottom

# --- labels: shore stretches per recording, from the app log (BT: last 10 s - rangefinder at its ringdown, bottom
#     track at the far end). Water = everything else, with a margin on both sides of each shore stretch left out.
SHORE = {
    '2D_pulse_log_2026.10.18_15.00.29.plog': ('15:00:29', '15:07:05', [('15:00:00', '15:00:50'), ('15:04:01', '15:04:38'), ('15:06:22', '15:08:00')]),
    'SS_pulse_log_2026.10.18_15.10.27.plog': ('15:10:27', '15:21:05', [('15:10:00', '15:10:52'), ('15:20:23', '15:22:00')]),
    # 19 Oct 2026 (pulse app log 19.10.2026.log): shore -> 10-20 cm -> mission -> shore, then the same with (15, 0.5, 0)
    '2D_pulse_log_2026.10.19_17.01.44.plog': ('17:01:44', '17:12:50', [('17:01:00', '17:02:22'), ('17:06:42', '17:07:12'), ('17:12:22', '17:13:00')]),
    'SS_pulse_log_2026.10.19_17.20.15.plog': ('17:20:15', '17:29:00', [('17:22:38', '17:23:33'), ('17:28:20', '17:29:00')]),
    '2D_pulse_log_2026.10.19_17.29.29.plog': ('17:29:29', '17:44:00', [('17:29:00', '17:29:50'), ('17:34:55', '17:35:40'), ('17:43:35', '17:44:00')]),
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

def gate_b(contrast, bt, rng=None, maxd=None):
    """Per epoch: the majority of the last GATE_B_WINDOW epochs (this one included) that have a bottom show no echo.
    Only a bottom beyond GATE_B_FROM_FRACTION of the reachable end can be weak."""
    weak = np.isfinite(bt) & ~(contrast >= GATE_B_CONTRAST)   # NaN contrast with a bottom counts as weak
    if rng is not None:
        weak &= bt > GATE_B_FROM_FRACTION * np.minimum(maxd, GATE_A_RANGE_FRACTION * rng)
    has = np.isfinite(bt)
    out = np.zeros(len(bt), bool)
    for i in range(len(bt)):
        a = max(0, i - GATE_B_WINDOW + 1)
        n = has[a:i + 1].sum(); w = weak[a:i + 1].sum()
        out[i] = has[i] and n > 0 and 2 * w > n
    return out

# the real slopes of the 18 Oct run (analysis 5.2 item 9): the outlier filter must reject nothing there
SLOPES = {
    '2D_pulse_log_2026.10.18_15.00.29.plog': [('15:01:40', '15:02:10')],   # red 1.4 -> 5.6 m
    'SS_pulse_log_2026.10.18_15.10.27.plog': [('15:15:21', '15:15:53')],   # blue 11 -> 2.5 m
    '2D_pulse_log_2026.10.19_17.01.44.plog': [('17:02:40', '17:03:10')], 'SS_pulse_log_2026.10.19_17.20.15.plog': [('17:24:00', '17:24:30')],
    '2D_pulse_log_2026.10.19_17.29.29.plog': [('17:30:15', '17:30:55')],
}

SECOND_ECHO_MIN, SECOND_ECHO_MAX = 1.7, 3.3   # P11 (depth_gates.h Params)

def second_echo_half(d, res, off, bt, ref):
    """P11 (depth_gates.h secondEchoHalf): the refined half position when bt is a second echo of ref, else NaN."""
    if not (np.isfinite(bt) and np.isfinite(ref) and ref > 0): return np.nan
    k = bt / ref
    if k < SECOND_ECHO_MIN or k > SECOND_ECHO_MAX: return np.nan
    n = len(d); w = int(GATE_B_PEAK_M / res)
    def peak(m):
        c = int((m - off) / res); a = max(0, c - w); b = min(n, c + w + 1)
        if b <= a: return -1, -1
        seg = d[a:b]; i = int(np.argmax(seg)); return int(seg[i]), a + i
    full, _ = peak(bt); half, at = peak(bt * 0.5)
    if full < 0 or half < 0 or half < full: return np.nan
    h = off + at * res
    if abs(h - ref) > max(outlier.ABS_M, outlier.REL * ref): return np.nan   # the half must BE the reference's bottom
    return h

def run_outlier(gated, times, eps=None):
    """The filter over the gated per-epoch values in epoch order, the window = the epochs of the last second
    (time, not samples, as Dataset counts them). With eps (the traces, as sweep.load gives them) P11 runs before the
    filter. Returns stored values, held mask, released count (and the second-echo mask when eps is given)."""
    f = outlier.OutlierFilter()
    stored = np.full(len(gated), np.nan); held = np.zeros(len(gated), bool); released = 0
    second = np.zeros(len(gated), bool)
    j = 0
    for i, v in enumerate(gated):
        while times[i] - times[j] > 1.0: j += 1
        w = i - j + 1
        if not np.isfinite(v):
            f.no_bottom(i); continue
        if eps is not None:
            d, res, off = eps[i]
            half = second_echo_half(d, res, off, float(v), f.reference(i, w))
            if np.isfinite(half):
                second[i] = True; v = half
        s, h, c, rel = f.apply(i, float(v), w)
        stored[i] = s; held[i] = h
        for k, x in rel:
            stored[k] = x; held[k] = False; released += 1
    if eps is not None:
        return stored, held, released, second
    return stored, held, released

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
    log_path = log_path
    start, end = SHORE[name][:2]
    times, info = epoch_times(log_path, len(bt), start, end)
    print(f'clock from {info[0]} LINK lines; file {start} + {info[1]} s, {len(bt)} epochs')
    shore, water = labels(name, times)
    f, r, con, lvl = feat.feats(plog_path, npz_path)
    A = gate_a(bt, rng, maxd); B = gate_b(con, bt, rng, maxd)
    report(name, bt, shore, water, {'A': A, 'B': B, 'A or B': A | B})
    gated = np.where(A | B, np.nan, bt)
    stored, held, released = run_outlier(gated, times)
    hw = water & np.isfinite(gated)
    def hms_(x): x = int(x); return f'{x // 3600:02d}:{x % 3600 // 60:02d}:{x % 60:02d}'
    print(f'  outlier    held in water {held[hw].sum()} of {hw.sum()} epochs ({100 * held[hw].mean():.2f}%), {released} released after a confirmed jump')
    for a, b in SLOPES[name]:
        m = (times >= hms(a)) & (times <= hms(b)) & np.isfinite(gated)
        print(f'  slope {a}-{b}: {np.nanmin(gated[m]):.2f} -> {np.nanmax(gated[m]):.2f} m, {m.sum()} epochs, held {held[m].sum()}')
    if held[hw].any():
        ks = np.where(held & hw)[0]
        print('  held at', sorted(set(hms_(times[k]) for k in ks))[:20], 'values', np.round(gated[ks], 2)[:20])
    np.savez(npz_path.replace('.npz', '_gates.npz'), A=A, B=B, times=times, shore=shore, water=water, con=con,
             stored=stored, held=held)

if __name__ == '__main__':
    main()
