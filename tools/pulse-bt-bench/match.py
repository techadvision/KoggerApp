import re, sys, numpy as np
log, npz, t0, t1 = sys.argv[1:5]
L = []
for l in open(log, errors='replace'):
    t = l[11:23]
    if not (t0 <= t <= t1): continue
    m = re.search(r'BT: epoch (\d+) \| bottom track ([\d.]+|-) m raw of ([\d.]+) m', l)
    if m and m.group(2) != '-': L.append((t, int(m.group(1)), float(m.group(2)), float(m.group(3))))
z = np.load(npz); W = z['writes']; rng = z['rng']
by = {}
for c, e, v in W:
    by.setdefault(int(e), []).append(v)
best = None
for off in range(-20000, 20000):
    hit = tot = 0
    for t, e, v, r in L[:80]:
        k = e - off
        if 0 <= k < len(rng):
            tot += 1
            if abs(rng[k] - r) < 0.02 and any(abs(x - v) < 0.011 for x in by.get(k, []) if x == x): hit += 1
    if tot and (best is None or hit > best[1]): best = (off, hit, tot)
print('lines', len(L), 'best offset', best)
off = best[0]; hit = tot = 0; miss = []
for t, e, v, r in L:
    k = e - off
    if 0 <= k < len(rng):
        tot += 1
        ws = [x for x in by.get(k, []) if x == x]
        ok = any(abs(x - v) < 0.011 for x in ws)
        hit += ok
        if not ok and len(miss) < 8: miss.append((t, k, v, r, round(rng[k], 2), [round(x, 2) for x in ws]))
print('all lines matched', hit, 'of', tot)
for m in miss: print(m)
