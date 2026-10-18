"""Parameter sweep of the bottom track on one recording: window, gain slope, vertical gap.

    python3 sweep.py <plog> <preset> <min> <max> [fill] [pings_per_s]

For each parameter set the recording is replayed through the port (bt.realtime), then judged three ways:
  raw        - the bottom track as the algorithm returns it
  gated      - after gates A and B and the outlier filter of the depth-source plan (what the app stores since P3-P5b)
  reference  - a centred rolling median (+-3 s) of the BASELINE run: an excursion shorter than ~3 s cannot move it,
               so it stands in for the true bottom on a slowly varying bottom (it is NOT ground truth)
Reported per set: false readings (> max(0.5 m, 30%) off the reference), the residual after the gates, what the gates
turned into a dash, the jitter (90th percentile of |delta| between consecutive epochs, the precision), and the delay the window
costs (windowSize/2 pings, since the window is centred)."""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import plog, bt, gates, outlier

def load(path, fill):
    plog.FILL_FROM_PREVIOUS = fill
    eps = []
    for e in plog.read(path):
        if e[0] != 'chart': continue
        ch = e[5]
        d = ((ch[0].astype(np.uint16) + ch[1].astype(np.uint16)) >> 2).astype(np.uint8) if len(ch) == 2 and len(ch[0]) == len(ch[1]) else ch[0]
        eps.append((d, e[3], e[4]))
    return eps

def contrast(eps, f):
    con = np.full(len(f), np.nan)
    for i, (d, res, off) in enumerate(eps):
        n = len(d); i0 = max(1, int(gates.GATE_B_SKIP_M / res))
        body = np.sort(d[i0:].astype(float))
        if not len(body) or not np.isfinite(f[i]): continue
        med = body[(len(body) - 1) // 2]
        k = int(f[i] / res); w = int(gates.GATE_B_PEAK_M / res); a = max(0, k - w); b = min(n, k + w + 1)
        con[i] = (d[a:b].max() if b > a else np.nan) / (med + 1)
    return con

def rolling_median(v, half):
    out = np.full(len(v), np.nan)
    for i in range(len(v)):
        s = v[max(0, i - half):i + half + 1]; s = s[np.isfinite(s)]
        if len(s): out[i] = np.median(s)
    return out

def judge(eps, cfg, maxd, times, ref):
    final, _ = bt.realtime([(d, r) for d, r, o in eps], cfg)
    rng = np.array([o + len(d) * r for d, r, o in eps])
    con = contrast(eps, final)
    A = gates.gate_a(final, rng, maxd); B = gates.gate_b(con, final, rng, maxd)
    gated = np.where(A | B, np.nan, final)
    stored, held, _ = gates.run_outlier(gated, times)
    fin = np.isfinite(final)
    off = np.abs(final - ref) > np.maximum(0.5, 0.3 * ref)
    sfin = np.isfinite(stored)
    soff = np.abs(stored - ref) > np.maximum(0.5, 0.3 * ref)
    d = np.diff(final); d = d[np.isfinite(d)]
    return dict(false=100 * (off & fin).sum() / max(1, fin.sum()), nan=100 * (~fin).mean(),
                gated_false=100 * (soff & sfin).sum() / max(1, sfin.sum()), gated_dash=100 * (~sfin).mean(),
                jitter=float(np.percentile(np.abs(d), 90)) if len(d) else np.nan, final=final)

def main():
    path = sys.argv[1]; preset = int(sys.argv[2]); mind = float(sys.argv[3]); maxd = float(sys.argv[4])
    fill = 'fill' in sys.argv[5:]
    pps = float([a for a in sys.argv[5:] if a != 'fill'][0]) if [a for a in sys.argv[5:] if a != 'fill'] else 14.0
    eps = load(path, fill)
    times = np.arange(len(eps)) / pps
    base = (preset, 5, 0.04, mind, maxd, 2, 0)
    fb, _ = bt.realtime([(d, r) for d, r, o in eps], base)
    ref = rolling_median(fb, int(3 * pps))
    print(f'{os.path.basename(path)}: {len(eps)} epochs, reference = +-3 s rolling median of the baseline {base}; '
          f'reference depth {np.nanpercentile(ref, 5):.2f}-{np.nanpercentile(ref, 95):.2f} m (5-95%)')
    print(f'{"W":>3} {"gain":>5} {"vgap":>5} | {"false%":>7} {"nan%":>5} | {"after gates: false%":>19} {"dash%":>6} | {"dd p90 m":>8} {"delay s":>7}')
    sets = []
    for W in (5, 9, 15, 21, 31):
        sets.append((W, 2, 0.04))
    for g in (0.5, 1, 2, 4, 8):
        sets.append((5, g, 0.04))
    for vg in (0.0, 0.02, 0.04, 0.08, 0.15):
        sets.append((5, 2, vg))
    for W, g in ((15, 1), (15, 0.5), (31, 1), (9, 1)):
        sets.append((W, g, 0.04))
    seen = set()
    for W, g, vg in sets:
        if (W, g, vg) in seen: continue
        seen.add((W, g, vg))
        r = judge(eps, (preset, W, vg, mind, maxd, g, 0), maxd, times, ref)
        print(f'{W:>3} {g:>5} {vg:>5} | {r["false"]:>7.2f} {r["nan"]:>5.1f} | {r["gated_false"]:>19.2f} {r["gated_dash"]:>6.1f} | {r["jitter"]:>8.3f} {W // 2 / pps:>7.2f}')

if __name__ == '__main__':
    main()
