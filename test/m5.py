import time, sys
sys.path.insert(0, "/tmp/t")
from vice import *
v = mlstart("/tmp/t/fbmlw.d64", d9="/tmp/t/big9.d64")
def hlrow():
    rv=v.rev_rows(); return [r for r in range(2,24) if rv[r]>10][0]
def goto(name):
    for i in range(70):
        if name in v.screen()[hlrow()]: return
        v.mkey(DOWN)
    raise RuntimeError(name)
goto("oxford pascal")
v.mkey(ord('4')); v.mtype(pet("oxford")); v.mkey(RET)
t0=time.time(); v.mtype([0x14]+pet("9")); v.mkey(RET, timeout=900)
print("oxford 8->9 took", time.time()-t0, v.screen()[hlrow()][:27])
# run ML at $c000 from drive 9 (mlc000 idx 50)
v.mkey(ord('1')); v.mtype([0x14]+pet("9")); v.mkey(RET)
v.mkey(RIGHT); v.mkey(RIGHT); goto("mlc000")
v.mkey(ord('7'))
print("ran:", v.screen()[hlrow() if False else 8][:27], "| row24:", v.screen()[24][:10])
v.show("after run $c000")
v.mkey(ord(' '))
print("back:", v.screen()[8][:27])
v.mkey(ord('8'))
print("load only:", [l[:27] for l in v.screen()[2:24] if 'Loaded' in l])
v.quit()
