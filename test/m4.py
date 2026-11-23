import time, sys
sys.path.insert(0, "/tmp/t")
from vice import *
t00=time.time()
v = mlstart("/tmp/t/fbmlw.d64", d9="/tmp/t/full9w.d64")
def hlrow():
    rv=v.rev_rows(); return [r for r in range(2,24) if rv[r]>10][0]
def goto(name):
    for i in range(60):
        r=hlrow()
        if name in v.screen()[r]: return
        v.mkey(DOWN)
    raise RuntimeError(name)
def copy(name, drive):
    v.mkey(ord('4')); v.mtype(pet(name)); v.mkey(RET)
    t0=time.time(); v.mtype([0x14]+pet(drive)); v.mkey(RET, timeout=900); return time.time()-t0
print("started", time.time()-t00)
goto("oxford pascal")
print("oxford -> 9 (disk full) took", copy("", "9"))
print("error:", v.screen()[2][:27], "|", v.screen()[3][:27])
v.mkey(RET); v.mtype([0x14]+pet("9")); v.mkey(RET)
print("drive 9 now:", [l[:27].strip() for l in v.screen()[2:6]])
v.mkey(DOWN)
print("on:", v.screen()[hlrow()][:27])
print("smallseq -> 8 took", copy("", "8"), "| row:", v.screen()[hlrow()][:27])
copy("", "8"); print("again:", v.screen()[2][:27])
v.mkey(RET)
v.shot("/tmp/t/sml_exists.png")
v.quit()
