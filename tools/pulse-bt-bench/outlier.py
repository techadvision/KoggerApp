"""Line-by-line port of depthgates::OutlierFilter (src/depth_gates.h, P5b). Keep the two in step."""
import math

ABS_M = 0.5
REL = 0.3
MIN_REFERENCE = 3
PERSIST_TENTHS = 7
JUMP_FREE_M = 2.0
JUMP_SECONDS_PER_M = 0.5
PERSIST_MAX_WINDOWS = 4
WITNESS_MAX_WINDOWS = 8
RETURN_WINDOWS = 15


def _median(v):
    v = sorted(v)
    return v[(len(v) - 1) // 2]


class OutlierFilter:
    def __init__(self):
        self.accepted = {}
        self.held = {}
        self.last_veto = -1
        self.prev_ref = math.nan; self.prev_ref_epoch = -1

    def _trim(self, before):
        self.accepted = {k: x for k, x in self.accepted.items() if k >= before}
        self.held = {k: x for k, x in self.held.items() if k >= before}

    def no_bottom(self, epoch):
        self.accepted.pop(epoch, None); self.held.pop(epoch, None)

    def reference(self, epoch, window_epochs):
        """The reference apply() would judge this epoch against (NaN when too few accepted) - for P11."""
        w = max(3, int(window_epochs))
        refs = [x for k, x in sorted(self.accepted.items(), reverse=True) if k < epoch][:w]
        return _median(refs) if len(refs) >= MIN_REFERENCE else math.nan

    def apply(self, epoch, value, window_epochs, witness=None):
        """Returns (stored, held, confirmed, released[(epoch, value)])."""
        w = max(3, int(window_epochs))
        self._trim(epoch - (PERSIST_MAX_WINDOWS + 4) * w)
        self.accepted.pop(epoch, None); self.held.pop(epoch, None)
        if value is None or not math.isfinite(value):
            return math.nan, False, False, []
        refs = [x for k, x in sorted(self.accepted.items(), reverse=True) if k < epoch][:w]   # the last w ACCEPTED
        if len(refs) < MIN_REFERENCE:
            self.accepted[epoch] = value
            return value, False, False, []
        ref = _median(refs)
        if abs(value - ref) <= max(ABS_M, REL * ref):
            self.accepted[epoch] = value
            return value, False, False, []
        if math.isfinite(self.prev_ref) and epoch - self.prev_ref_epoch <= RETURN_WINDOWS * w and abs(value - self.prev_ref) <= max(ABS_M, REL * self.prev_ref):
            self.accepted[epoch] = value       # the return to the bottom a confirmed jump left behind
            return value, False, False, []
        self.held[epoch] = value
        jump = abs(value - ref)
        span_w = min(1.0 + max(0.0, jump - JUMP_FREE_M) * JUMP_SECONDS_PER_M, float(PERSIST_MAX_WINDOWS))
        if witness is not None and math.isfinite(witness) and abs(witness - ref) <= max(ABS_M, REL * ref) and abs(witness - value) > max(ABS_M, REL * value):
            self.last_veto = epoch
        if self.last_veto >= 0 and epoch - self.last_veto < w:
            span_w = max(span_w, float(WITNESS_MAX_WINDOWS))
        span = int(span_w * w + 0.5)
        hv = sorted((k, x) for k, x in self.held.items() if epoch - span + 1 <= k <= epoch)
        need = max(MIN_REFERENCE, (PERSIST_TENTHS * span + 9) // 10)
        if len(hv) >= need:
            hm = _median([x for k, x in hv]); tol = max(ABS_M, REL * hm)
            if all(abs(x - hm) <= tol for k, x in hv):
                released = []
                for k, x in hv:
                    self.accepted[k] = x; self.held.pop(k, None)
                    if k != epoch: released.append((k, x))
                if not math.isfinite(self.prev_ref) or epoch - self.prev_ref_epoch > RETURN_WINDOWS * w or abs(ref - self.prev_ref) > max(ABS_M, REL * self.prev_ref):
                    self.prev_ref = ref; self.prev_ref_epoch = epoch
                return value, False, True, released
        return math.nan, True, False, []
