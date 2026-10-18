"""Minimal .plog reader: KP1 frames (BB 55 addr mode id len payload ck1 ck2)."""
import struct, numpy as np
FILL_FROM_PREVIOUS = False   # the black-stripe processor (blue, 1 step forward) fills lost fragments from the previous ping
ID_DIST, ID_CHART, ID_TIMESTAMP = 0x02, 0x03, 0x01

def frames(buf):
    i, n = 0, len(buf)
    bad = 0
    while i < n - 8:
        if buf[i] != 0xBB or buf[i+1] != 0x55:
            j = buf.find(b'\xBB\x55', i+1)
            if j < 0: break
            i = j; continue
        L = buf[i+5]; end = i + 8 + L
        if end > n: break
        body = buf[i+2:end-2]
        c1 = c2 = 0
        for b in body:
            c1 = (c1 + b) & 0xFF; c2 = (c2 + c1) & 0xFF
        if c1 == buf[end-2] and c2 == buf[end-1]:
            mode = buf[i+3]
            yield buf[i+2], mode & 3, (mode >> 3) & 7, buf[i+4], buf[i+6:end-2]
            i = end
        else:
            bad += 1; i += 2

def read(path):
    """Returns list of events: ('chart', addr, ver, res_m, off_m, [arrays]) / ('dist', addr, metres)"""
    buf = open(path, 'rb').read()
    ev = []
    st = {}   # per (addr) chart assembler
    for addr, typ, ver, fid, pl in frames(buf):
        if typ != 1: continue   # CONTENT only
        if fid == ID_DIST and ver == 0 and len(pl) >= 4:
            ev.append(('dist', addr, struct.unpack_from('<I', pl)[0] / 1000.0))
        elif fid == ID_CHART and ver in (0, 1) and len(pl) >= 6:
            seq, res, aoff = struct.unpack_from('<HHH', pl)
            data = pl[6:]
            s = st.setdefault(addr, {'fill': bytearray(), 'res': None, 'aoff': None, 'ver': ver, 'gaps': [], 'prev': None})
            if (seq == 0 and len(s['fill']) > 0) or (s['res'] is not None and (s['res'] != res or s['aoff'] != aoff)):
                if s['res']:
                    f = np.frombuffer(bytes(s['fill']), dtype=np.uint8).copy()
                    if FILL_FROM_PREVIOUS and s['prev'] is not None and len(s['prev']) == len(f):
                        for a, b in s['gaps']:
                            f[a:b] = s['prev'][a:b]
                    s['prev'] = f
                    chans = [f] if s['ver'] == 0 else [f[0::2], f[1::2]]
                    ev.append(('chart', addr, s['ver'], s['res'] / 1000.0, s['aoff'] * s['res'] / 1000.0, chans))
                s['fill'] = bytearray(); s['gaps'] = []
            s['res'], s['aoff'], s['ver'] = res, aoff, ver
            if len(s['fill']) < seq:
                s['gaps'].append((len(s['fill']), seq))
                s['fill'] += bytes(seq - len(s['fill']))   # lost fragment -> zeros (then optionally the previous ping)
            if len(s['fill']) == seq:
                s['fill'] += data
    return ev
