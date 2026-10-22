import sys, numpy as np
sys.path.insert(0, sys.path[0]); import tvg
from strips import render
logs = [('andy',1000,'ANDY 25m'),('2026.10.19_17.20.15',1675,'19Oct 25m'),('2026.10.22_08.17.44',679,'Max 25m'),
        ('2026.10.18_15.10.27',1675,'18Oct 25m'),('2026.10.18_15.10.27',2500,'18Oct 50m')]
def bottom_mask(raw, res):
    w = max(3, int(0.3/res))
    k = np.ones(w)/w
    sm = np.apply_along_axis(lambda x: np.convolve(x, k, 'same'), 1, raw.astype(float))
    i0 = int(1.0/res)
    wc = np.median(sm[:, i0:i0+int(1.5/res)], axis=1)
    thr = np.maximum(wc*2.5, wc+25)
    m = np.zeros(raw.shape, bool); valid = np.zeros(raw.shape[0], bool)
    for j in range(raw.shape[0]):
        hit = np.where(sm[j, i0:] > thr[j])[0]
        if len(hit) and (i0+hit[0])*res < 0.6*raw.shape[1]*res:
            b = i0+hit[0]+int(0.5/res); m[j, b:] = True; valid[j] = True
    return m, valid
if __name__ == '__main__':
    for key, n, lab in logs:
        d = np.load(sys.argv[1]+'/'+key+'.npz'); meta, A, N = d['meta'], d['A'], d['N']
        idx = np.where(N == n)[0][::6]
        res, off = float(meta[idx[0]][0]), float(meta[idx[0]][1])
        raw = A[idx, :, :n].reshape(-1, n)
        m, valid = bottom_mask(raw, res)
        raw, m = raw[valid], m[valid]
        R = n*res
        edges = np.linspace(0, R, 11)
        def prof(v):
            out=[]
            for a,b in zip(edges[:-1],edges[1:]):
                i0,i1=int(a/res),int(b/res); mm=m[:,i0:i1]
                out.append(v[:,i0:i1][mm].mean() if mm.sum()>500 else np.nan)
            return np.array(out)
        rp = prof(raw.astype(float))
        rc = (edges[:-1]+edges[1:])/2; ok = ~np.isnan(rp) & (rc > 3)
        slope = np.polyfit(np.log10(rc[ok]), 20*np.log10(rp[ok]), 1)[0]
        print(f"\n{lab}: {valid.sum()} bottom pings, raw mean of bottom by range bin ({R/10:.1f} m bins):")
        print("  bins  ", ' '.join(f"{x:5.1f}" for x in rc))
        print("  raw   ", ' '.join(f"{x:5.1f}" for x in rp), f"  falloff {slope:.1f} dB/decade (as 20log10 of the 8-bit value)")
        for name, p in [("AGC", None), ("S0 b0", dict(S=0, beta=0)), ("NOW 7.5/10", dict(rref=10, beta=0.9)),
                        ("7.5/20", dict(rref=20, beta=0.9)), ("S5/10", dict(S=5, rref=10, beta=0.9)),
                        ("S10/10", dict(S=10, rref=10, beta=0.9)), ("S12.5/10", dict(S=12.5, rref=10, beta=0.9)),("S15/10", dict(S=15, rref=10, beta=0.9))]:
            sub = raw if p is not None else raw[::3]
            v = tvg.display(render(sub, res, off, p))
            mm_save = m
            if p is None: m = m[::3]
            pv = prof(v); m = mm_save
            sat = (v[(m if p is not None else m[::3])] >= 0.999).mean()
            print(f"  {name:11s}", ' '.join(f"{x*100:5.0f}" for x in pv), f"  sat {sat*100:4.1f}%  far/near {np.nanmean(pv[-3:])/np.nanmean(pv[ok][:2]):.2f}")
