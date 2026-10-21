"""P11 (the second echo) measured: gates + filter with and without it, on every recording.

    python3 benchp11.py <bench dir>

Truth = a rolling median of the run itself (+-10 s for ANDY, whose far features persist for 5 s and more; +-3 s else)."""
import numpy as np, sys
sys.path.insert(0,'tools/pulse-bt-bench'); import gates, sweep, feat
H=sys.argv[1].rstrip('/')+'/'   # the bench dir with the npz files; run from the repo root
for name,npz,log,lab in [('SS_pulse_log_ANDY_2026.10.03_11.16.09.plog','andy.npz',None,'andy'),('SS_pulse_log_2026.10.18_15.10.27.plog','blue.npz','pulse_181026.log','blue18'),('SS_pulse_log_2026.10.19_17.20.15.plog','blue19.npz','pulse app log 19.10.2026.log','blue19'),('2D_pulse_log_2026.10.18_15.00.29.plog','red.npz','pulse_181026.log','red18'),('SS_pulse_log_2026.10.21_18.22.01.plog','blue21.npz',None,'blue21')]:
    z=np.load(H+npz); bt=z['final']; rng=z['rng']; maxd=35.0 if name.startswith('SS') else 50.0
    eps=sweep.load('testlogs/depth-source/'+name, name.startswith('SS'))
    f,r,con,lvl=feat.feats('testlogs/depth-source/'+name,H+npz)
    if log:
        times,_=gates.epoch_times('testlogs/depth-source/'+log,len(bt),*gates.SHORE[name][:2]); shore,water=gates.labels(name,times)
    else: times=np.arange(len(bt))/14.0; water=np.ones(len(bt),bool); shore=~water
    A=gates.gate_a(bt,rng,maxd); B=gates.gate_b(con,bt,rng,maxd); gated=np.where(A|B,np.nan,bt)
    s0,h0,r0=gates.run_outlier(gated,times)
    s1,h1,r1,sec=gates.run_outlier(gated,times,eps)
    fin=np.isfinite(bt)
    if lab=='blue21': good=fin&(bt<1); false=fin&(bt>=1); ref=np.where(bt<1,bt,np.nan)
    else:
        ref=sweep.rolling_median(bt,140 if lab=="andy" else 42); off=np.abs(bt-ref)>np.maximum(0.5,0.3*ref); good=fin&water&~off; false=fin&water&off
    def bad(s): return np.isfinite(s)&water&(np.abs(s-ref)>np.maximum(0.5,0.3*ref))
    print(f"{lab}: water epochs {water.sum()} | false shown after gates+filter: {bad(s0).sum()} -> with P11: {bad(s1).sum()} | P11 fired on {sec.sum()} epochs ({(sec&good).sum()} good, {(sec&false).sum()} false) | dashed in water: {(~np.isfinite(s0)&water&fin).sum()} -> {(~np.isfinite(s1)&water&fin).sum()} | held {h0.sum()} -> {h1.sum()}")
    if (sec&good).any():
        k=np.where(sec&good)[0][:10]; print('   P11 on good at', k, 'bt', np.round(bt[k],2), 'stored', np.round(s1[k],2), 'ref', np.round(ref[k],2))
