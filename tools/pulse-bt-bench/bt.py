"""Faithful port of BottomTrackProcessor::bottomTrackProcessing (src/data_processor/bottom_track_processor.cpp)
and of DataProcessor's realtime pass schedule (indexFrom = prevTo - W, indexTo = currTo, one new epoch a pass).
Integer semantics follow the C++ (int32, truncating division)."""
import math
import numpy as np
from numba import njit

PRESETS = {  # istart_ref, init_win_ref, scale_win_ref, c1..c5, s2..s5, t1
    0: (4, 6, 20, (-6, 6, 4, 2, 0), (1.04, 1.06, 1.10, 1.15), 1.07),
    1: (4, 6, 35, (-3, 8, 5, -1, -1), (1.015, 1.035, 1.08, 1.12), 1.04),
    2: (4, 6, 12, (-3, -3, 4, 2, 1), (1.1, 1.2, 1.3, 1.4), 1.2),
}

def lround(x):
    return int(math.floor(x + 0.5)) if x >= 0 else -int(math.floor(-x + 0.5))

@njit(cache=True)
def epoch_cash(data, cash, istart, init_win, init_scale_term_q12, scale_win_q12,
               c1, c2, c3, c4, c5, s2, s3, s4, s5, init_win_scaled, q12, gsi):
    """Fills cash (int32, len == len(data)) in place, exactly as the C++ does. Returns nothing."""
    n = data.shape[0]
    data_from = istart
    data_to = istart + init_win
    acc = 0
    for i in range(istart, istart + init_win):
        acc += data[i]
    avr = init_win
    idata = istart
    while idata + avr < n:
        if data_from >= n or data_to >= n:
            break
        acc -= data[data_from]; data_from += 1
        acc += data[data_to]; data_to += 1
        while data_to < n:
            avr = data_to - data_from
            if ((idata << 12) + init_scale_term_q12) >= avr * scale_win_q12:
                acc += data[data_to]; data_to += 1
            else:
                break
        cash[idata] = np.int32((10 * acc) // avr)
        idata += 1
    conv = n - avr
    idata = istart
    while True:
        fid = np.float32(idata) + np.float32(init_win_scaled) + np.float32(1.0)
        d2 = int(fid * np.float32(s2)); d3 = int(fid * np.float32(s3))
        d4 = int(fid * np.float32(s4)); d5 = int(fid * np.float32(s5))
        if d5 >= conv:
            break
        calc = np.int32(c1 * cash[idata] + c2 * cash[d2] + c3 * cash[d3] + c4 * cash[d4] + c5 * cash[d5])
        ref = (idata * q12 + 2048) >> 12
        if ref < 0:
            ref = 0
        calc = np.int32(np.int64(calc) * gsi + np.int64(calc) * ref)
        cash[idata] = calc
        idata += 1


class Pass:
    def __init__(self, preset, W, vgap, mind, maxd, gain, thr):
        self.p = PRESETS[preset]; self.W = W; self.vgap = vgap; self.mind = mind; self.maxd = maxd
        self.gsi = int(1000 / gain); self.thr_int = int(10 * self.gsi * 1000 * thr)

    def run(self, epochs, i0, i1, n_all=None):
        """epochs: list of (data uint8 array, res). Processes [i0-W/2, i1+W/2) as one call; returns
        {epoch: distance or nan} for i0..i1-1 (what is published)."""
        istart_ref, init_win_ref, scale_win_ref, (c1, c2, c3, c4, c5), (s2, s3, s4, s5), t1 = self.p
        W = self.W
        n_all = len(epochs) if n_all is None else n_all
        emin = max(0, i0 - W // 2); emax = min(n_all, i1 + W // 2)
        cash = [np.zeros(0, np.int32) for _ in range(W)]
        summ = np.zeros(0, np.int64)
        bt = np.full(emax - emin, np.nan)
        sc = np.full(emax - emin, np.nan)
        counter = 0; active_res = None
        istart = init_win = 0; init_win_scaled = 0.0; q12 = 1; init_scale_term_q12 = 0; scale_win_q12 = 0
        for ie in range(emin, emax):
            data, res = epochs[ie]
            if data is None or not res > 0:
                continue
            if active_res is None or abs(res - active_res) > 1e-6:
                ss = np.float32(0.01) / np.float32(res)
                istart = max(0, lround(float(istart_ref * ss)))
                init_win_scaled = float(np.float32(init_win_ref) * ss)
                init_win = max(1, lround(init_win_scaled))
                q12 = max(1, lround(float(np.float32(res) / np.float32(0.01)) * 4096))
                scale_win_q12 = scale_win_ref << 12
                init_scale_term_q12 = max(1, lround(init_win_scaled * scale_win_q12))
                if active_res is not None:
                    summ = np.zeros(0, np.int64)
                    cash = [np.zeros(0, np.int32) for _ in range(W)]
                    counter = 0
                active_res = res
            n = data.shape[0]
            if n <= istart + init_win:
                continue
            counter += 1
            ci = (counter - 1) % W; bi = counter % W
            if counter >= W:
                b = cash[bi]
                summ[istart:len(b)] -= b[istart:]
            if len(cash[ci]) != n:
                old = cash[ci]; new = np.zeros(n, np.int32); k = min(len(old), n); new[:k] = old[:k]; cash[ci] = new
            epoch_cash(data.astype(np.int64), cash[ci], istart, init_win, init_scale_term_q12, scale_win_q12,
                       c1, c2, c3, c4, c5, s2, s3, s4, s5, init_win_scaled, q12, self.gsi)
            col = len(cash[ci])
            if len(summ) < col:
                s = np.zeros(col, np.int64); s[:len(summ)] = summ; summ = s
            summ[istart:col] += cash[ci][istart:]
            wc = (counter - 1 + W // 2) % W
            sf = self.mind; st = self.maxd
            ssi = int(np.float32(sf) / np.float32(t1) / np.float32(res)); esi = int(np.float32(st) / np.float32(t1) / np.float32(res))
            ssi = min(max(ssi, 0), len(summ)); esi = min(max(esi, 0), len(summ))
            max_val = self.thr_int * W; max_ind = -1
            if esi > ssi:
                seg = summ[ssi:esi]
                j = int(np.argmax(seg))
                if seg[j] > max_val:
                    max_ind = ssi + j
            if max_ind > 0:
                dist = (max_ind + init_win_scaled + 1.0) * t1 * res
                if counter >= W and self.vgap > 0:
                    cc = cash[wc]
                    sg = int(max_ind * (1.0 - self.vgap)); eg = int(max_ind * (1.0 + self.vgap))
                    sg = max(sg, ssi); sg = min(sg, len(cc))
                    eg = max(eg, 0); eg = min(eg, len(cc)); eg = min(eg, esi)
                    mg = 0; mgi = -1
                    if eg > sg:
                        seg = cc[sg:eg]; j = int(np.argmax(seg))
                        if seg[j] > 0:
                            mgi = sg + j
                    if mgi > 0:
                        dist = (mgi + init_win_scaled + 1.0) * t1 * res
                k = (ie - emin - W // 2) if counter >= W else (ie - emin - counter // 2)
                if 0 <= k < len(bt):
                    bt[k] = dist
                    sc[k] = float(summ[max_ind]) / W
        self.last_score = {ie: sc[ie - emin] for ie in range(i0, i1)}
        return {ie: bt[ie - emin] for ie in range(i0, i1)}


LOOKAHEAD = 2   # the app processes with the dataset size, which runs ~2 epochs ahead of the chart counter (matches its ~1% no-bottom rate)

def realtime(epochs, cfg):
    """Every pass the app would run, one new epoch at a time. Returns (final[epoch], writes) where
    writes is the list of (pass_end_epoch, epoch, value) in publish order (what the readout sees)."""
    P = Pass(*cfg); W = cfg[1]
    final = np.full(len(epochs), np.nan); score = np.full(len(epochs), np.nan); writes = []
    prev = 0
    for cur in range(W, len(epochs) + 1):
        i0 = max(0, prev - W)
        out = P.run(epochs, i0, cur, min(len(epochs), cur + LOOKAHEAD))
        for ie in range(i0, cur):
            final[ie] = out[ie]; score[ie] = P.last_score[ie]; writes.append((cur - 1, ie, out[ie]))
        prev = cur
    realtime.score = score
    return final, writes
