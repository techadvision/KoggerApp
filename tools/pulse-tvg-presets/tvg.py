"""Python port of EchogramSideScanTvg::apply and Epoch::Echogram::updateCompesated (AGC)."""
import numpy as np
FLOOR_DB, R0, BOOST_WIN_M = -12.0, 0.5, 0.4

def gain(n, res, off, S=7.5, a=0.0, rref=10.0, cap=40.0):
    r = off + np.arange(n) * res
    rr = np.maximum(r, R0)
    g = S * (np.log10(rr) - np.log10(rref)) + a * (r - rref)
    g = np.clip(g, FLOOR_DB, cap)
    return 10 ** (g * 0.05)

def tvg(raw, res, off, S=7.5, a=0.0, rref=10.0, cap=40.0, nf=0.0, beta=0.9):
    raw = raw.astype(np.float32); n = raw.shape[-1]
    g = gain(n, res, off, S, a, rref, cap)
    v = raw * g                      # nf = 0 at release; not modelled
    if beta <= 0.01:
        return np.clip(np.floor(v + 0.5), 0, 255)
    v = np.maximum(v, 0)
    win = int(BOOST_WIN_M / res + 0.5); win = min(max(win, 3), 101); win |= 1
    k = np.ones(win) / win
    # centred box blur (edges approximated by 'same' with edge padding)
    pad = win // 2
    vp = np.pad(v, [(0, 0)] * (v.ndim - 1) + [(pad, pad)], mode='edge')
    cs = np.cumsum(vp, axis=-1); cs = np.concatenate([np.zeros(cs.shape[:-1] + (1,)), cs], axis=-1)
    blur = (cs[..., win:] - cs[..., :-win]) / win
    out = v + beta * (v - blur)
    return np.clip(np.floor(out + 0.5), 0, 255)

def agc(raw, res):
    out = np.zeros(raw.shape, np.float32)
    for j in range(raw.shape[0]):
        src = raw[j].astype(np.float32); avrg = 255.0; o = out[j]
        for i in range(src.shape[0]):
            val = src[i]
            avrg += (val - avrg) * (0.05 + avrg * 0.0006)
            val = (val - avrg * 0.55) * (0.85 + i * res * 0.006) * 2.0
            o[i] = 0 if val < 0 else (255 if val > 255 else val)
    return np.floor(out)

def display(v, low=0, high=80):
    """Plot2DEchogram::updateColors levels (0..100 units x 2.55) -> 0..1 grey."""
    lo, hi = low * 2.55, high * 2.55
    return np.clip((v - lo) / (hi - lo), 0, 1)
