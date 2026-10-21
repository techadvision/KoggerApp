"""The blue's parameter sets replayed on the ANDY gravel pit, step 1: the bottom track per set, saved to ~/bench/sweep3.npz
with a truth = +-10 s rolling median of the per-epoch median across all sets. Run from the repo root; then sweep3b.py."""
import numpy as np, sys, os, time
sys.path.insert(0,'tools/pulse-bt-bench'); import sweep, bt as BT
name='SS_pulse_log_ANDY_2026.10.03_11.16.09.plog'; eps=sweep.load('testlogs/depth-source/'+name, True)
SETS=[(5,2,0.04),(5,1,0.04),(5,1,0.0),(9,1,0.0),(15,1,0.0),(15,0.5,0.0),(31,1,0.0),(9,0.5,0.0)]
out={}
for W,g,vg in SETS:
    t=time.time(); f,_=BT.realtime([(d,r) for d,r,o in eps],(2,W,vg,0.25,35.0,g,0)); out[f'{W}_{g}_{vg}']=f; print(W,g,vg,'%.0fs'%(time.time()-t),flush=True)
allm=np.nanmedian(np.vstack(list(out.values())),axis=0); out['truth']=sweep.rolling_median(allm,140)
np.savez(os.path.expanduser('~/bench/sweep3.npz'),**out)
