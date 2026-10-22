import sys, numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, sys.path[0]); import tvg
name, outdir = sys.argv[1], sys.argv[2]
d = np.load(sys.argv[1] + '.npz'); meta, A, N = d['meta'], d['A'], d['N']
key = name.split('/')[-1]
# per dominant config
cfgs = {}
for i,(res,off) in enumerate(meta):
    cfgs.setdefault((round(res*1000), int(N[i])), []).append(i)
for (rmm, n), idx in sorted(cfgs.items(), key=lambda kv: -len(kv[1]))[:2]:
    if len(idx) < 500: continue
    idx = np.array(idx)
    step = max(1, len(idx) // 1500)
    sel = idx[::step]
    res = rmm / 1000.0
    rows = []
    for j in sel:
        l = tvg.tvg(A[j,0,:n][None], res, meta[j][1])[0]; r = tvg.tvg(A[j,1,:n][None], res, meta[j][1])[0]
        rows.append(np.concatenate([l[::-1], r]))
    img = tvg.display(np.array(rows))
    # shrink across-track to 800 px
    im = Image.fromarray((img * 255).astype(np.uint8)).resize((800, len(rows)))
    dr = ImageDraw.Draw(im)
    for k in range(0, len(sel), 100):
        dr.text((2, k), str(int(sel[k])), fill=255)
    fn = f"{outdir}/overview_{key}_{rmm}mm_{n}.png"; im.save(fn); print(fn, len(idx), 'pings, step', step, 'range/side', n*res)
