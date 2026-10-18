"""Line-by-line port of depthgates::OutlierFilter (src/depth_gates.h, P5b). Keep the two in step."""
import math

ABS_M = 0.5
REL = 0.3
MIN_REFERENCE = 3
PERSIST_TENTHS = 7


def _median(v):
    v = sorted(v)
    return v[(len(v) - 1) // 2]


class OutlierFilter:
    def __init__(self):
        self.accepted = {}
        self.held = {}

    def _trim(self, before):
        self.accepted = {k: x for k, x in self.accepted.items() if k >= before}
        self.held = {k: x for k, x in self.held.items() if k >= before}

    def no_bottom(self, epoch):
        self.accepted.pop(epoch, None); self.held.pop(epoch, None)

    def apply(self, epoch, value, window_epochs):
        """Returns (stored, held, confirmed, released[(epoch, value)])."""
        w = max(3, int(window_epochs))
        self._trim(epoch - 4 * w)
        self.accepted.pop(epoch, None); self.held.pop(epoch, None)
        if value is None or not math.isfinite(value):
            return math.nan, False, False, []
        refs = [x for k, x in self.accepted.items() if epoch - w <= k < epoch]
        if len(refs) < MIN_REFERENCE:
            self.accepted[epoch] = value
            return value, False, False, []
        ref = _median(refs)
        if abs(value - ref) <= max(ABS_M, REL * ref):
            self.accepted[epoch] = value
            return value, False, False, []
        self.held[epoch] = value
        hv = sorted((k, x) for k, x in self.held.items() if epoch - w + 1 <= k <= epoch)
        need = max(MIN_REFERENCE, (PERSIST_TENTHS * w + 9) // 10)
        if len(hv) >= need:
            hm = _median([x for k, x in hv]); tol = max(ABS_M, REL * hm)
            if all(abs(x - hm) <= tol for k, x in hv):
                released = []
                for k, x in hv:
                    self.accepted[k] = x; self.held.pop(k, None)
                    if k != epoch: released.append((k, x))
                return value, False, True, released
        return math.nan, True, False, []
