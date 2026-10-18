import sys, numpy as np
sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__))); import plog
def feats(path, npz):
    z=np.load(npz); f=z['final']; r=z['rng']; res=z['res']
    ev=[e for e in plog.read(path) if e[0]=='chart']
    con=np.full(len(f),np.nan); lvl=np.full(len(f),np.nan)
    for i,e in enumerate(ev):
        ch=e[5]   # the trace the bottom track itself sees: two sub-channels merged as (a + b) >> 2 (bottom_track_processor.cpp)
        d=(((ch[0].astype(np.uint16)+ch[1].astype(np.uint16))>>2).astype(float) if len(ch)==2 and len(ch[0])==len(ch[1]) else ch[0].astype(float))
        n=len(d); i0=max(1,int(0.4/res[i]))   # skip the first 0.4 m (ringdown)
        body=d[i0:]
        med=np.median(body) if len(body) else np.nan
        lvl[i]=med
        if f[i]==f[i]:
            k=int(f[i]/res[i]); a=max(0,k-int(0.1/res[i])); b=min(n,k+int(0.1/res[i])+1)
            con[i]=(d[a:b].max() if b>a else np.nan)/(med+1)
    return f,r,con,lvl
