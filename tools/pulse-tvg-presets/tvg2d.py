"""Python port of EchogramTvg::apply (the 2D echogram law) plus P5's noise-floor step, for the offline strips.
Law: gain(z) = 10^(k z / 20), z = off + i res, capped at 30x; k = 0.9 dB/m default.
P5 floor: a low percentile (FLOOR_PCT, 30th) of the raw samples from SURF_BAND_MAX_M (1.0 m, below the ring-down) to
the end of the trace, clamped at NOISE_FLOOR_MAX (80, as side scan); strength x floor is subtracted before the gain.
The plan said median; the offline check (7 Nov 2026) showed the band under the bottom - a bottom tail of ~70 raw that
is there with the motor off too - takes 30-45% of a trace once the planner keeps the bottom at 0.6 of the range, so the
median lands 10-50 raw units above the water column and the subtraction eats the water column's own texture and the
weak features in it. The 30th percentile sits within a few units of the water column median on all four recordings
(under it, never over, on Olav's)."""
import numpy as np
GAIN_CAP, SURF_BAND_MAX_M, NOISE_FLOOR_MAX, MIN_SPAN, FLOOR_PCT, DAMAGED_SHARE = 30.0, 1.0, 80.0, 16, 30, 0.6

def gain(n, res, off, k=0.9):
    z = max(off, 0.0) + np.arange(n) * res
    return np.minimum(10 ** (k * z / 20.0), GAIN_CAP)

def floor(raw, res, off, pct=None):
    """per-ping floor estimate (raw units); 0 when the trace is too short to judge"""
    n = raw.shape[-1]
    i0 = max(0, int((SURF_BAND_MAX_M - off) / res + 0.5))
    if n - i0 < MIN_SPAN:
        return np.zeros(raw.shape[:-1], np.float32)
    t = raw[..., i0:].astype(np.float32)
    if t.ndim == 1:
        nz = t[t > 0]                     # lost fragments are exact zeros; a ping the black-stripes repair has not
        if len(nz) < MIN_SPAN or len(nz) < DAMAGED_SHARE * len(t):   # filled is not judged (fail-safe: no subtraction)
            return np.float32(0.0)
        t = nz
        p = FLOOR_PCT if pct is None else pct
        return np.float32(min(np.sort(t)[(len(t) - 1) * p // 100], NOISE_FLOOR_MAX))   # as nth_element in echogram_tvg.cpp
    f = np.array([floor(r, res, off, pct) for r in raw], np.float32)
    return f

def tvg(raw, res, off, k=0.9, nf=0.0, pct=None):
    raw = raw.astype(np.float32); n = raw.shape[-1]
    if k <= 0 or res <= 0:
        return raw
    v = raw
    if nf > 0.001:
        v = np.maximum(raw - (nf * floor(raw, res, off, pct))[..., None], 0.0)
    v = v * gain(n, res, off, k)
    return np.clip(np.floor(v + 0.5), 0, 255)

def display(v, low=0, high=80):
    lo, hi = low * 2.55, high * 2.55
    return np.clip((v - lo) / (hi - lo), 0, 1)
