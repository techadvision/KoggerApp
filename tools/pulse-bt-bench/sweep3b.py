"""Step 2: each set judged through the whole pipeline (A, B, P11, the filter with the return rule) against the truth of
sweep3a.py. python3 sweep3b.py 5_2_0.04 15_0.5_0.0 ... (a few per call - the Python filter loop is slow)."""
import numpy as np, sys, os
sys.path.insert(0,'tools/pulse-bt-bench'); import gates, sweep
name='SS_pulse_log_ANDY_2026.10.03_11.16.09.plog'; eps=sweep.load('testlogs/depth-source/'+name, True)
rng=np.array([o+len(d)*r for d,r,o in eps]); times=np.arange(len(eps))/14.0
z=np.load(os.path.expanduser('~/bench/sweep3.npz')); truth=z['truth']
for key in sys.argv[1:]:
    f=z[key]; fin=np.isfinite(f); W=int(key.split('_')[0])
    off=lambda s: np.isfinite(s)&(np.abs(s-truth)>np.maximum(0.5,0.3*truth))
    con=sweep.contrast(eps,f); A=gates.gate_a(f,rng,35.0); B=gates.gate_b(con,f,rng,35.0); gated=np.where(A|B,np.nan,f)
    s,h,r,sec=gates.run_outlier(gated,times,eps)
    # longest false-shown run
    bad=off(s); runs=[]; 
    for k in np.where(bad)[0]:
        if runs and k-runs[-1][-1]<=3: runs[-1].append(k)
        else: runs.append([k])
    longest=max((len(x) for x in runs),default=0)/14
    print(f'{key:>10} | raw false {100*off(f).sum()/fin.sum():5.2f}% | shown false {100*bad.sum()/len(f):5.2f}% (longest run {longest:.1f} s, {len(runs)} runs) | dashed {100*(~np.isfinite(s)).mean():4.1f}% | P11 {sec.sum():3d} | delay {W//2/14:.2f} s',flush=True)
