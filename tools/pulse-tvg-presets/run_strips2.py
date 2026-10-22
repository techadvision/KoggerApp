import sys; sys.path.insert(0, sys.path[0]); from strips import *
P2 = [
 ("Off (AGC)",          None),
 ("LOW  S5 ref10",      dict(S=5,   rref=10, beta=0.9)),
 ("MED  S7.5 ref10=NOW",dict(S=7.5, rref=10, beta=0.9)),
 ("BRIGHT S10 ref10",   dict(S=10,  rref=10, beta=0.9)),
 ("alt S12.5 ref10",    dict(S=12.5,rref=10, beta=0.9)),
 ("Olav ref15 S7.5",    dict(S=7.5, rref=15, beta=0.9)),
 ("Olav ref20 S7.5",    dict(S=7.5, rref=20, beta=0.9)),
 ("NOW + boost 1.5",    dict(S=7.5, rref=10, beta=1.5)),
]
O = sys.argv[1]; T = sys.argv[2]
strip(T+'/2026.10.19_17.20.15', 5000, 500, 1, (5, 13), (13, 25), '19 Oct blue 25 m', O+'/B_strip_1019_5000.png', P2)
strip(T+'/2026.10.19_17.20.15', 3450, 500, 0, (0, 10), (10, 25), '19 Oct blue 25 m (rocky shallows)', O+'/B_strip_1019_3450.png', P2)
strip(T+'/2026.10.22_08.17.44', 12000, 900, 1, (5, 13), (13, 25), 'Max 22 Oct blue 25 m', O+'/B_strip_max_12000.png', P2)
strip(T+'/2026.10.18_15.10.27', 5000, 600, 0, (5, 20), (25, 50), '18 Oct blue 50 m (ripples)', O+'/B_strip_1018_5000.png', P2)
strip(T+'/andy', 3150, 450, 1, (1, 9), (12, 25), 'ANDY 3 Oct blue 25 m', O+'/B_strip_andy_3150.png', P2)
