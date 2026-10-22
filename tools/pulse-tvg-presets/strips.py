import sys, numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, sys.path[0]); import tvg
PRESETS = [
 ("Off (AGC)",        None),
 ("ref 10 b0.9 NOW",  dict(rref=10, beta=0.9)),
 ("ref 15 b0.9",      dict(rref=15, beta=0.9)),
 ("ref 20 b0.9",      dict(rref=20, beta=0.9)),
 ("ref 30 b0.9",      dict(rref=30, beta=0.9)),
 ("ref 10 b1.5",      dict(rref=10, beta=1.5)),
 ("ref 15 b1.5",      dict(rref=15, beta=1.5)),
 ("ref 20 b1.5",      dict(rref=20, beta=1.5)),
]
def render(raw, res, off, p):
    if p is None: return tvg.agc(raw, res)
    return tvg.tvg(raw, res, off, **p)

def strip(npz, start, count, side, near, far, title, out, presets=PRESETS, colw=230):
    d = np.load(npz + '.npz'); meta, A, N = d['meta'], d['A'], d['N']
    idx = np.arange(start, start + count)
    n = int(np.bincount(N[idx]).argmax()); idx = idx[N[idx] == n]
    res, off = float(meta[idx[0]][0]), float(meta[idx[0]][1])
    raw = A[idx, side, :n]
    crops = [('near', near), ('far', far)]
    head = 34
    W = colw * len(presets); H = head + 2 * (len(idx) + 18)
    im = Image.new('L', (W, H), 40); dr = ImageDraw.Draw(im)
    dr.text((4, 2), f"{title}  pings {idx[0]}-{idx[-1]}  {res*1000:.0f} mm x {n} = {n*res:.1f} m/side  side {'port' if side==0 else 'stbd'}  levels 0..80 (intensity 10)", fill=255)
    for c, (name, p) in enumerate(presets):
        v = tvg.display(render(raw, res, off, p))
        dr.text((c * colw + 4, 18), name, fill=255)
        y = head
        for cname, (r0, r1) in crops:
            i0, i1 = int((r0 - off) / res), min(n, int((r1 - off) / res))
            tile = Image.fromarray((v[:, i0:i1] * 255).astype(np.uint8)).resize((colw - 6, len(idx)))
            im.paste(tile, (c * colw + 3, y + 14))
            dr.text((c * colw + 4, y + 1), f"{cname} {r0:g}-{r1:g} m", fill=200)
            y += len(idx) + 18
    im.save(out); print(out)

def metrics(npz, cfg_n, bands, every=5, presets=PRESETS):
    d = np.load(npz + '.npz'); meta, A, N = d['meta'], d['A'], d['N']
    idx = np.where(N == cfg_n)[0][::every]
    res, off = float(meta[idx[0]][0]), float(meta[idx[0]][1])
    raw = A[idx, :, :cfg_n].reshape(-1, cfg_n)
    # in-water pings only: raw mean over 1..R/2 above a floor and not flat noise
    rows = []
    for name, p in presets:
        v = tvg.display(render(raw, res, off, p)) if p is not None or len(raw) < 4000 else None
        if v is None:
            sub = raw[::4]; v = tvg.display(render(sub, res, off, p))
        r = []
        for (b0, b1) in bands:
            i0, i1 = int((b0 - off) / res), min(cfg_n, int((b1 - off) / res))
            x = v[:, i0:i1]
            r.append((x.mean(), (x >= 0.999).mean(), (x < 0.04).mean()))
        rows.append((name, r))
    return rows
