"""P5 of the motor-noise plan - the 2D noise-floor strips.
    python3 strips2d.py <cache dir> <out dir>
One image per window: the same pings at floor strength 0 / 0.3 / 0.6 / 1.0 (EchogramTvg law, k 0.9, grey levels
0..80), depth axis in metres so a resolution change inside the window does not move the picture, the bench's
bottom track in red. Prints, per window and strength: the display mean 0.5-1.5 m under the bottom, the water
column mean (1 m .. bottom - 0.3 m), the bottom peak, and how much of the water column's visible texture
(display > 0.25 at strength 0) is still visible."""
import sys, os, numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import tvg2d
STRENGTHS = [0.0, 0.3, 0.6, 1.0]
WINDOWS = [  # (cache, first ping, count, label)
 ('andy1142', 1500, 400, 'Andy 11:42 noisy, 4 m'), ('andy1142', 1800, 400, 'Andy 11:42 quiet, 4 m'),
 ('andy1142', 4500, 400, 'Andy 11:42 noisy, 4 m (b)'), ('andy1142', 6000, 400, 'Andy 11:42 quiet, 4 m (b)'),
 ('andy1142', 2400, 400, 'Andy 11:42 shallows 0.5-2 m'),
 ('andy1128', 900, 400, 'Andy 11:28 noisy, 4-5 m in 9 m'), ('andy1128', 1500, 400, 'Andy 11:28 noisy, 5 m in 10 m'),
 ('andy1156', 600, 400, 'Andy 11:56, 4 m'),
 ('olav1606', 1200, 400, 'Olav 16:06, 3.6 m in 6 m'), ('olav1606', 300, 400, 'Olav 16:06, 4.8 m in 7 m'),
 ('olav1606', 6300, 400, 'Olav 16:06, 4.2 m in 12 m'),
]
PX_PER_M, COLW, GAP = 60, 400, 8

def window(cache, start, count):
    d = np.load(cache + '.npz'); meta, A, N, bt = d['meta'], d['A'], d['N'], d['bt']
    idx = np.arange(start, min(start + count, len(N)))
    return [(meta[i][0], meta[i][1], A[i, :N[i]], bt[i]) for i in idx]

def panel(pings, nf, rmax):
    H = int(rmax * PX_PER_M); img = np.zeros((H, len(pings)), np.float32)
    for c, (res, off, raw, bt) in enumerate(pings):
        v = tvg2d.display(tvg2d.tvg(raw, res, off, nf=nf))
        z = (np.arange(H) + 0.5) / PX_PER_M
        j = ((z - off) / res).astype(int); ok = (j >= 0) & (j < len(raw))
        img[ok, c] = v[j[ok]]
    return img

def metrics(pings, nf):
    under, water, peak, keep0, keepn = [], [], [], 0, 0
    for res, off, raw, bt in pings:
        if not np.isfinite(bt) or bt < 1.6: continue
        v0 = tvg2d.display(tvg2d.tvg(raw, res, off, nf=0.0)); v = tvg2d.display(tvg2d.tvg(raw, res, off, nf=nf))
        rng = off + len(raw) * res
        w0, w1 = int((1.0 - off) / res), int((bt - 0.3 - off) / res)
        if w1 > w0:
            water.append(v[w0:w1].mean()); vis = v0[w0:w1] > 0.25; keep0 += vis.sum(); keepn += (v[w0:w1][vis] > 0.25).sum()
        p0, p1 = max(0, int((bt - 0.1 - off) / res)), min(len(v), int((bt + 0.1 - off) / res))
        if p1 > p0: peak.append(v[p0:p1].max())
        if bt + 1.5 < rng:
            u0, u1 = int((bt + 0.5 - off) / res), int((bt + 1.5 - off) / res); under.append(v[u0:u1].mean())
    f = lambda a: np.mean(a) if a else float('nan')
    return f(under), f(water), f(peak), (keepn / keep0 if keep0 else float('nan'))

def main():
    cache, out = sys.argv[1], sys.argv[2]; os.makedirs(out, exist_ok=True)
    print('window | strength | under-bottom 0.5-1.5 m | water column | bottom peak | water texture kept')
    for name, start, count, label in WINDOWS:
        pings = window(os.path.join(cache, name), start, count)
        rmax = max(off + len(raw) * res for res, off, raw, bt in pings)
        H = int(rmax * PX_PER_M); head = 36
        im = Image.new('RGB', (len(STRENGTHS) * (COLW + GAP), head + H + 16), (40, 40, 40)); dr = ImageDraw.Draw(im)
        dr.text((4, 2), f'{label}  pings {start}-{start+len(pings)-1}  0..{rmax:.1f} m  k 0.9 dB/m, grey levels 0..80, red = bench bottom track', fill=(255, 255, 255))
        for c, nf in enumerate(STRENGTHS):
            img = panel(pings, nf, rmax)
            tile = Image.fromarray((img * 255).astype(np.uint8)).convert('RGB').resize((COLW, H))
            x0 = c * (COLW + GAP)
            im.paste(tile, (x0, head))
            sx = COLW / len(pings)
            for i, (res, off, raw, bt) in enumerate(pings):
                if np.isfinite(bt): dr.point((x0 + int(i * sx), head + int(bt * PX_PER_M)), fill=(255, 60, 60))
            dr.text((x0 + 4, 20), f'noise floor {nf:g}', fill=(255, 255, 255))
            for m in range(1, int(rmax) + 1):
                dr.line((x0, head + m * PX_PER_M, x0 + 6, head + m * PX_PER_M), fill=(120, 200, 255)); dr.text((x0 + 8, head + m * PX_PER_M - 6), f'{m}', fill=(120, 200, 255))
            u, w, p, k = metrics(pings, nf)
            print(f'{label:32s} | {nf:3.1f} | {u:5.2f} | {w:5.2f} | {p:5.2f} | {k:5.2f}')
        fn = os.path.join(out, f'{name}_{start}.png'); im.save(fn); print(' ->', fn)

if __name__ == '__main__': main()
