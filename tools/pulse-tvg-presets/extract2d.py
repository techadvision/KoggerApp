"""P5 of the motor-noise plan: extract the 2D pings of a .plog (ID_CHART v0, one channel) into a numpy cache
and run the bottom-track bench on them, so the noise-floor strips can be judged against the bottom.
    python3 extract2d.py ../pulse-bt-bench <plog> <out-prefix> [bt cfg tuple, default red/black] [fill]
`fill` reads lost fragments from the previous ping, as the app's black-stripes repair does before the TVG runs.
Writes <out>.npz: meta (res m, off m) per ping, A (pings x L, uint8), N (samples per ping), bt (bottom m, NaN = none)."""
import sys, time, numpy as np
sys.path.insert(0, sys.argv[1])
import plog, bt
path, out = sys.argv[2], sys.argv[3]
cfg = eval(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4] != 'fill' else (1, 5, 0.04, 0.25, 50, 2, 0)
plog.FILL_FROM_PREVIOUS = 'fill' in sys.argv[4:]
ev = plog.read(path)
P = [(e[3], e[4], e[5][0]) for e in ev if e[0] == 'chart' and e[2] == 0 and len(e[5]) == 1]
print(path.split('/')[-1], 'pings', len(P))
t = time.time()
final, writes = bt.realtime([(d, r) for r, o, d in P], cfg)
print(' bottom track', round(time.time() - t, 1), 's; no-bottom', int(np.sum(~np.isfinite(np.array(final, float)))))
L = max(len(d) for r, o, d in P)
A = np.zeros((len(P), L), np.uint8); N = np.zeros(len(P), np.int32)
for i, (r, o, d) in enumerate(P):
    A[i, :len(d)] = d; N[i] = len(d)
np.savez_compressed(out + '.npz', meta=np.array([(r, o) for r, o, d in P]), A=A, N=N, bt=np.array(final, np.float32))
