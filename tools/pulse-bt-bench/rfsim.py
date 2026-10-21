"""The rangefinder's steady reading and its veto (depth_gates.h: rfSteadyReading, rfVeto, 21 Oct 2026), replayed
from an APP LOG's SHALLOW: lines - the .plog has no rangefinder, so this is the only bench these two rules have.

    python3 rfsim.py <app log> <date YYYY-MM-DD> [HH:MM:SS-HH:MM:SS]

Per 5 s: how many epochs each rule would route where (veto = no bottom from either source; rf = rangefinder shallow
mode; bt = bottom track; none = no raw bottom), the dominant one and its value range. The shore state, gates A/B
and the outlier filter are NOT simulated here - a 'bt' at the floor (0.32-0.37) is normally the shore state's.
Mirrors the constants of ChoiceParams; change one and the other."""
import re, sys, statistics as st
from collections import defaultdict, Counter
F = sys.argv[1]; DAY = sys.argv[2]
win = sys.argv[3] if len(sys.argv) > 3 else None
def hms(x): h, m, s = map(int, x.split(':')); return h * 3600 + m * 60 + s
lo, hi = (hms(win.split('-')[0]), hms(win.split('-')[1])) if win else (0, 10**9)
RINGDOWN, RINGLOW, ENTER, STAY, MAXM, RATIO, RFENTER, FLOORMARGIN, ECHO_MIN, ECHO_MAX = 0.25, 0.16, 0.03, 0.06, 1.0, 4.0, 0.5, 0.12, 1.7, 3.3
rows=[]
for l in open(F,errors='ignore'):
    if not l.startswith(DAY) or 'SHALLOW:' not in l: continue
    m=re.search(r'(\d\d:\d\d:\d\d)\.(\d+) .*bottom track ([\d.]+|-) m raw( \(at its floor\))? \| rangefinder live ([\d.]+) \(([\d.]+) s',l)
    if not m: continue
    h,mi,s=map(int,m.group(1).split(':')); t=h*3600+mi*60+s+int(m.group(2))/1000
    bt=float(m.group(3)) if m.group(3)!='-' else float('nan'); rf=float(m.group(5)); floor=bool(m.group(4))
    if lo <= t <= hi: rows.append((t,bt,rf,floor))
sec=defaultdict(list)
for r in rows: sec[int(r[0])].append(r)
steady=None; out=[]
for k in sorted(sec):
    v=sec[k]; rfs=sorted(r for _,_,r,_ in v if r>0)
    med=None
    if len(rfs)>=3:
        sp=rfs[-1]-rfs[0]; m=rfs[len(rfs)//2]
        if sp<=(STAY if steady is not None else ENTER)+1e-4 and RINGLOW<m<MAXM: med=m
    steady=med
    # per epoch decision (the shore state, A/B and the outlier filter are not simulated)
    res=[]
    for t,bt,rf,floor in v:
        if bt!=bt: res.append(('none',None)); continue
        if steady is not None and (steady<=RINGDOWN or bt>RATIO*steady): res.append(('veto',None)); continue
        # shallow: steady>0.25 and rf<0.5 and agrees
        agrees = floor or (bt<=0.25+FLOORMARGIN) or (rf>0 and ECHO_MIN<=bt/rf<=ECHO_MAX)
        if steady is not None and steady>RINGDOWN and rf<RFENTER and agrees: res.append(('rf',rf)); continue
        res.append(('bt',bt))
    out.append((k,res,steady))
# print per 5 s: dominant source and value range
b=defaultdict(list)
for k,res,sd in out: b[k//5*5].extend(res)
for k in sorted(b):
    v=b[k]
    c=Counter(s for s,_ in v); dom=c.most_common(1)[0][0]
    vals=[x for s,x in v if s==dom and x is not None]
    rng="%.2f-%.2f"%(min(vals),max(vals)) if vals else ''
    print("%02d:%02d:%02d"%(k//3600,k%3600//60,k%60), " ".join("%s:%d"%(s,n) for s,n in c.most_common()), "|", dom, rng)
