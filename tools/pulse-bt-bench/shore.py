"""The shore state and the held bottom (Dataset::publishPass / chooseDepth, depth_gates.h ChoiceParams), replayed from
.plog files alone: the trace (95th percentile past 0.4 m on channel 0, the echo contrast on the merged trace), the raw
bottom track (bt.py, red/black profile) and the rangefinder ($SDDBT sentences, mapped to the epoch they follow).

    python3 shore.py <plog> [<plog> ...] [--rate 13] [--no-held] [--runs]

Per file: epochs in the shore state without and with the held bottom, the ones the held bottom takes out of it (their
raw depth range) and the shore epochs left with a raw bottom track of 1 m or more. --runs lists the shore stretches
that remain. Built 7 Nov 2026 for the black at 710/810 kHz (its rangefinder gives up past ~9.3 m, its deep trace is
quiet, and the depth went to a dash in stable deep water).

Approximations: one pass per epoch and a fixed ping rate (--rate, pings/s) for the 1 s vote and the 1.5 s ringdown
window - the app counts passes on the wall clock. Against the app's 7 Nov 'BT: last 10 s' shore counts it lands on the
same 10 s windows. 2D presets only (the side scan path has no held bottom). Mirrors ChoiceParams; change them together."""
import sys, os, re, bisect, struct, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bt

RINGDOWN_M, FAR_NOISE_M, FAR_NOISE_SPREAD = 0.25, 30.0, 0.15
QUIET_P95_RED, FLOOR_ZONE = 60, 0.25 + 0.18            # minDistance + floorMargin
FROZEN_SPREAD_M, FROZEN_MAX_M = 0.03, 1.0
HELD_MIN_M, HELD_CONTRAST, HELD_SPREAD_ABS_M, HELD_SPREAD_REL = 1.5, 10.0, 0.3, 0.05
PROFILE = (1, 5, 0.04, 0.25, 50, 2, 0)                 # red/black

def frames_off(buf):
    i, n = 0, len(buf)
    while i < n - 8:
        if buf[i] != 0xBB or buf[i+1] != 0x55:
            j = buf.find(b'\xBB\x55', i + 1)
            if j < 0: break
            i = j; continue
        L = buf[i+5]; end = i + 8 + L
        if end > n: break
        c1 = c2 = 0
        for b_ in buf[i+2:end-2]: c1 = (c1 + b_) & 0xFF; c2 = (c2 + c1) & 0xFF
        if c1 == buf[end-2] and c2 == buf[end-1]:
            mode = buf[i+3]; yield i, buf[i+2], mode & 3, (mode >> 3) & 7, buf[i+4], buf[i+6:end-2]; i = end
        else:
            i += 2

def features(path):
    buf = open(path, 'rb').read()
    ev, ends, st = [], [], {}
    for off, addr, typ, ver, fid, pl in frames_off(buf):
        if typ != 1 or fid != 3 or ver not in (0, 1) or len(pl) < 6: continue
        seq, res, aoff = struct.unpack_from('<HHH', pl); data = pl[6:]
        s = st.setdefault(addr, {'fill': bytearray(), 'res': None, 'aoff': None, 'ver': ver})
        if (seq == 0 and len(s['fill']) > 0) or (s['res'] is not None and (s['res'] != res or s['aoff'] != aoff)):
            if s['res']:
                f = np.frombuffer(bytes(s['fill']), dtype=np.uint8).copy()
                ev.append((s['res'] / 1000.0, s['aoff'] * s['res'] / 1000.0, [f] if s['ver'] == 0 else [f[0::2], f[1::2]]))
                ends.append(off)
            s['fill'] = bytearray()
        s['res'], s['aoff'], s['ver'] = res, aoff, ver
        if len(s['fill']) < seq: s['fill'] += bytes(seq - len(s['fill']))
        if len(s['fill']) == seq: s['fill'] += data
    N = len(ev); rf = np.full(N, np.nan)
    for m in re.finditer(rb'\$..DBT,[^,]*,f,([0-9.]*),M', buf):
        k = bisect.bisect_left(ends, m.start())
        if k < N and m.group(1): rf[k] = float(m.group(1))
    eps = []
    for res, o, ch in ev:
        d = ((ch[0].astype(np.uint16) + ch[1].astype(np.uint16)) >> 2).astype(np.uint8) if len(ch) == 2 and len(ch[0]) == len(ch[1]) else ch[0]
        eps.append((d, res, o, ch[0]))
    raw, _ = bt.realtime([(d, r) for d, r, o, c in eps], PROFILE)
    raw = np.array(raw, float); p95 = np.full(N, -1); con = np.full(N, np.nan)
    for i, (d, res, o, c0) in enumerate(eps):
        i0 = max(1, int((0.4 - o) / res))
        if i0 < len(c0):
            body = np.sort(c0[i0:]); p95[i] = body[min(len(body) - 1, len(body) * 95 // 100)]
            b2 = np.sort(d[i0:]); med = int(b2[(len(b2) - 1) // 2])
            if raw[i] == raw[i]:
                k = int((raw[i] - o) / res); w = int(0.1 / res); a = max(0, k - w); b = min(len(d), k + w + 1)
                if b > a: con[i] = d[a:b].max() / (med + 1)
    return raw, rf, p95, con

def held(raw, con, i, R):
    b = raw[i]
    if not np.isfinite(b) or b < HELD_MIN_M or not (con[i] >= HELD_CONTRAST): return False
    w = raw[max(0, i - R + 1):i + 1]; w = w[np.isfinite(w)]
    if len(w) < 3: return False
    return 3 * (np.abs(w - b) <= max(HELD_SPREAD_ABS_M, HELD_SPREAD_REL * b)).sum() >= 2 * len(w)

def shore_state(raw, rf, p95, con, R, use_held=True):
    N = len(raw); W15 = int(round(1.5 * R)); shore = np.zeros(N, bool); vote = np.zeros(N, bool)
    for i in range(N):
        r = rf[max(0, i - W15 + 1):i + 1]; r = r[np.isfinite(r) & (r > 0)]
        far = r[r >= FAR_NOISE_M]
        fn = len(far) >= 2 and 2 * len(far) >= len(r) and (far.max() - far.min()) > FAR_NOISE_SPREAD * far.min()
        ring = len(r) >= 2 and 3 * ((r <= RINGDOWN_M).sum() + (len(far) if fn else 0)) >= 2 * len(r)
        quiet = 0 <= p95[i] <= QUIET_P95_RED
        if use_held and quiet and held(raw, con, i, R): quiet = False
        floor = np.isfinite(raw[i]) and raw[i] <= FLOOR_ZONE
        w = raw[max(0, i - R + 1):i + 1]; w = w[np.isfinite(w)]
        frozen = len(w) >= 3 and (w.max() - w.min()) <= FROZEN_SPREAD_M and w.max() < FROZEN_MAX_M
        vote[i] = quiet or floor or frozen
        v = vote[max(0, i - R + 1):i + 1]
        shore[i] = ring and len(v) >= 3 and 3 * v.sum() >= 2 * len(v)
    return shore

if __name__ == '__main__':
    a = sys.argv[1:]; R = 13
    if '--rate' in a: R = int(round(float(a[a.index('--rate') + 1]))); del a[a.index('--rate'):a.index('--rate') + 2]
    runs = '--runs' in a; a = [x for x in a if not x.startswith('--')]
    for path in a:
        raw, rf, p95, con = features(path)
        s0 = shore_state(raw, rf, p95, con, R, False); s1 = shore_state(raw, rf, p95, con, R, True)
        out = s0 & ~s1; left = s1 & (raw >= 1.0)
        rr = '%.2f-%.2f m' % (np.nanmin(raw[out]), np.nanmax(raw[out])) if out.any() else '-'
        print('%s: %d epochs | shore %d -> %d with the held bottom | taken out %d (raw %s) | left at 1 m or more %d'
              % (os.path.basename(path), len(raw), s0.sum(), s1.sum(), out.sum(), rr, left.sum()))
        if runs:
            idx = np.where(s1)[0]; st = []
            for i in idx:
                if st and i == st[-1][1] + 1: st[-1][1] = i
                else: st.append([i, i])
            for x, y in st:
                print('    shore epochs %d-%d (~%.0f s in) raw %.2f-%.2f m' % (x, y, x / R, np.nanmin(raw[x:y+1]), np.nanmax(raw[x:y+1])))
