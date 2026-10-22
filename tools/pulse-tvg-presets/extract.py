import sys, numpy as np, collections
sys.path.insert(0, sys.argv[1])
import plog
path, out = sys.argv[2], sys.argv[3]
ev = plog.read(path)
P=[]
for e in ev:
    if e[0]=='chart' and e[2]==1:
        res, off, ch = e[3], e[4], e[5]
        P.append((res, off, ch[0], ch[1]))
print(path.split('/')[-1], 'pings', len(P))
c = collections.Counter((round(p[0]*1000), len(p[2])) for p in P)
print(' (res mm, samples/side):', c.most_common(8))
# store: group as object arrays
np.save(out, np.array([(p[0],p[1]) for p in P]), allow_pickle=False)
L = max(len(p[2]) for p in P)
A = np.zeros((len(P), 2, L), np.uint8); N = np.zeros(len(P), np.int32)
for i,p in enumerate(P):
    n=len(p[2]); A[i,0,:n]=p[2]; A[i,1,:n]=p[3]; N[i]=n
np.savez_compressed(out+'.npz', meta=np.array([(p[0],p[1]) for p in P]), A=A, N=N)
