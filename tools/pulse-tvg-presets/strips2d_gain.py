"""The 2D TVG level candidates (filter-modes plan, step 5) - offline before any preset is chosen.
    python3 strips2d_gain.py <cache dir> <out dir>
One image per window: the same pings at k = 0 (TVG off) and the candidate constants, EchogramTvg law, noise floor
0, grey levels 0..80, depth axis in metres; red = the bench's bottom track, orange = twice it (where a second echo
sits). Prints per window and k: water column mean (1 m .. bottom - 0.3 m), bottom peak, second-echo peak
(2 x bottom +- 0.2 m), its contrast against the band above it (1.5..1.8 x bottom), and the saturated share of the
trace (display = 1). Caches come from extract2d.py."""
import sys, os, numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import tvg2d
from strips2d import window, PX_PER_M
KS = [0.0, 0.5, 0.6, 0.75, 0.9, 1.05, 1.2, 1.4]
COLW, GAP = 200, 6
WINDOWS = [
 ('olav1542', 300, 400, 'Olav 15:42 2nd echo on, 3 m'), ('olav1542', 1500, 400, 'Olav 15:42 2nd echo on, 5.7 m'),
 ('olav1606', 6300, 400, 'Olav 16:06 2nd echo on, 4 m'), ('olav1606', 7800, 400, 'Olav 16:06 2nd echo on, 12 m'),
 ('andy1128', 2700, 400, 'Andy 11:28 noisy, 3.5 m'), ('andy1142', 1800, 400, 'Andy 11:42 quiet, 4 m'),
]

def disp(raw, res, off, k):
    return tvg2d.display(tvg2d.tvg(raw, res, off, k=k) if k > 0 else raw.astype(np.float32))

def metrics(pings, k):
    water, peak, sec, con, sat = [], [], [], [], []
    for res, off, raw, bt in pings:
        v = disp(raw, res, off, k); sat.append((v >= 1.0).mean())
        if not np.isfinite(bt) or bt < 1.2: continue
        ix = lambda z: int((z - off) / res)
        w0, w1 = ix(1.0), ix(bt - 0.3)
        if w1 > w0: water.append(v[w0:w1].mean())
        p0, p1 = max(0, ix(bt - 0.1)), min(len(v), ix(bt + 0.1))
        if p1 > p0: peak.append(v[p0:p1].max())
        s0, s1 = ix(2 * bt - 0.2), ix(2 * bt + 0.2)
        if s1 < len(v) and s1 > s0:
            a0, a1 = ix(1.5 * bt), ix(1.8 * bt)
            sec.append(v[s0:s1].max()); con.append(v[s0:s1].max() - v[a0:a1].mean())
    f = lambda a: np.mean(a) if a else float('nan')
    return f(water), f(peak), f(sec), f(con), f(sat)

def main():
    cache, out = sys.argv[1], sys.argv[2]; os.makedirs(out, exist_ok=True)
    print('window | k dB/m | water column | bottom peak | 2nd echo peak | 2nd echo contrast | saturated')
    for name, start, count, label in WINDOWS:
        pings = window(os.path.join(cache, name), start, count)
        rmax = max(off + len(raw) * res for res, off, raw, bt in pings)
        H = int(rmax * PX_PER_M) if rmax < 16 else int(rmax * 30); ppm = H / rmax; head = 36
        im = Image.new('RGB', (len(KS) * (COLW + GAP), head + H + 16), (40, 40, 40)); dr = ImageDraw.Draw(im)
        dr.text((4, 2), f'{label}  pings {start}-{start+len(pings)-1}  0..{rmax:.1f} m  grey 0..80, red bottom, orange 2 x bottom', fill=(255, 255, 255))
        for c, k in enumerate(KS):
            img = np.zeros((H, len(pings)), np.float32)
            for col, (res, off, raw, bt) in enumerate(pings):
                v = disp(raw, res, off, k); z = (np.arange(H) + 0.5) / ppm
                j = ((z - off) / res).astype(int); ok = (j >= 0) & (j < len(raw)); img[ok, col] = v[j[ok]]
            x0 = c * (COLW + GAP)
            im.paste(Image.fromarray((img * 255).astype(np.uint8)).convert('RGB').resize((COLW, H)), (x0, head))
            sx = COLW / len(pings)
            for i, (res, off, raw, bt) in enumerate(pings):
                if np.isfinite(bt):
                    dr.point((x0 + int(i * sx), head + int(bt * ppm)), fill=(255, 60, 60))
                    if 2 * bt < rmax: dr.point((x0 + int(i * sx), head + int(2 * bt * ppm)), fill=(255, 170, 40))
            dr.text((x0 + 4, 20), 'TVG off' if k == 0 else f'k {k:g} dB/m', fill=(255, 255, 255))
            w, p, s, cn, st = metrics(pings, k)
            print(f'{label:32s} | {k:4.2f} | {w:5.2f} | {p:5.2f} | {s:5.2f} | {cn:5.2f} | {st:5.3f}')
        fn = os.path.join(out, f'gain_{name}_{start}.png'); im.save(fn); print(' ->', fn)

if __name__ == '__main__': main()
