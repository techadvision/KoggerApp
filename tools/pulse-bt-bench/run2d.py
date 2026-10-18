import sys, time, numpy as np
sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
import plog, bt
f = sys.argv[1]; cfg = eval(sys.argv[2]); plog.FILL_FROM_PREVIOUS = len(sys.argv) > 4 and sys.argv[4] == 'fill'
ev = plog.read(f)
eps = []
for e in ev:
    if e[0] != 'chart': continue
    ch = e[5]
    if len(ch) == 2 and len(ch[0]) == len(ch[1]):
        d = ((ch[0].astype(np.uint16) + ch[1].astype(np.uint16)) >> 2).astype(np.uint8)
    else:
        d = ch[0]
    eps.append((d, e[3], e[4]))
t = time.time()
final, writes = bt.realtime([(d, r) for d, r, o in eps], cfg)
rng = np.array([o + len(d) * r for d, r, o in eps])
np.savez(sys.argv[3], final=final, rng=rng, res=np.array([r for d, r, o in eps]),
         n=np.array([len(d) for d, r, o in eps]), score=bt.realtime.score,
         mean=np.array([float(d[len(d)//10:].mean()) for d, r, o in eps]), p95=np.array([float(np.percentile(d,95)) for d, r, o in eps]), writes=np.array(writes))
print(len(eps), 'epochs', round(time.time() - t, 1), 's')
