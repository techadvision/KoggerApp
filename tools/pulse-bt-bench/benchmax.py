"""Max's 22 Oct quarry-lake run (blue, IP): the parameter sets of ~/bench/max.npz (made by the one-off max1 step: bt.realtime per set)
over the first 70 s - the glide into the water - and the rangefinder's quality against the bottom. python3 benchmax.py"""
import numpy as np, sys, os, re
sys.path.insert(0,'tools/pulse-bt-bench'); import sweep
z=np.load(os.path.expanduser('~/bench/max.npz')); keys=[k for k in z.files if k!='rng']
PPS=19.5
allm=np.nanmedian(np.vstack([z[k] for k in keys]),axis=0); truth=sweep.rolling_median(allm,int(10*PPS))
print('set        | raw false% | jitter p90 cm | first 70 s (every 3 s, m)')
for k in keys:
    f=z[k]; fin=np.isfinite(f); off=np.abs(f-truth)>np.maximum(0.5,0.3*truth)
    d=np.abs(np.diff(f)); d=d[np.isfinite(d)]
    seq=' '.join('%4.1f'%f[int(i*PPS)] if np.isfinite(f[int(i*PPS)]) else '  - ' for i in range(0,70,3))
    print(f'{k:>10} | {100*(off&fin).sum()/fin.sum():9.2f} | {100*np.percentile(d,90):12.0f} | {seq}')
# DBT from the plog, position-mapped to epochs
data=open('testlogs/depth-source/SS_pulse_log_2026.10.22_08.17.44.plog','rb').read()
dbt=[(m.start()/len(data)*len(allm),float(m.group(1))) for m in re.finditer(rb'\$SDDBT,[\d.]*,f,([\d.]+),M',data)]
rf=np.full(len(allm),np.nan)
for p,v in dbt: rf[min(len(rf)-1,int(p))]=v
seq=' '.join('%4.1f'%np.nanmedian(rf[int(i*PPS):int((i+3)*PPS)]) if np.isfinite(rf[int(i*PPS):int((i+3)*PPS)]).any() else '  - ' for i in range(0,70,3))
print(f'{"DBT":>10} | {len(dbt)} readings |               | {seq}')
# rangefinder quality over the run: readings vs truth where truth 1-10 m
m=np.isfinite(rf)&np.isfinite(truth)&(truth>1)&(truth<10)
agree=np.abs(rf[m]-truth[m])<=np.maximum(0.3,0.1*truth[m]); ring=rf[m]<=0.25; spike=rf[m]>1.5*truth[m]
print(f'rangefinder in 1-10 m water: {m.sum()} readings | within 10% of the bottom {100*agree.mean():.0f}% | at its ringdown (<=0.25) {100*ring.mean():.0f}% | spikes > 1.5 x {100*spike.mean():.0f}%')
