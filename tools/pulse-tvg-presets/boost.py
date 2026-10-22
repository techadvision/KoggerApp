import sys, numpy as np; sys.path.insert(0, sys.path[0]); import tvg
from profile import bottom_mask
for key, n, lab in [('2026.10.19_17.20.15',1675,'19Oct'),('2026.10.22_08.17.44',679,'Max'),('andy',1000,'ANDY'),('2026.10.18_15.10.27',2500,'18Oct 50m')]:
    d = np.load(sys.argv[1]+'/'+key+'.npz'); meta, A, N = d['meta'], d['A'], d['N']
    idx = np.where(N == n)[0][::10]; res, off = float(meta[idx[0]][0]), float(meta[idx[0]][1])
    raw = A[idx, :, :n].reshape(-1, n); m, valid = bottom_mask(raw, res); raw, m = raw[valid], m[valid]
    wc = np.zeros_like(m); i0=int(1.0/res)
    for j in range(len(m)):
        b = np.argmax(m[j]); wc[j, i0:max(i0, b-int(0.7/res))] = True
    out=[]
    for beta in (0.9, 1.2, 1.5):
        v = tvg.display(tvg.tvg(raw, res, off, S=7.5, rref=10, beta=beta))
        hp = v - np.apply_along_axis(lambda x: np.convolve(x, np.ones(9)/9, 'same'), 1, v)
        out.append(f"b{beta}: bottom mean {v[m].mean()*100:4.1f} detail(std hp) {hp[m].std()*100:4.1f} | water-col speckle {v[wc].std()*100:4.1f} sat {(v[m]>=.999).mean()*100:.2f}%")
    print(lab, *out, sep='\n  ')
