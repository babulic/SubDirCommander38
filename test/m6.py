import time, sys, shutil
sys.path.insert(0, "/tmp/t")
from vice import *
def hlrow(v):
    rv=v.rev_rows(); return [r for r in range(2,24) if rv[r]>10][0]
def goto(v, name):
    for i in range(70):
        if name in v.screen()[hlrow(v)]: return
        v.mkey(DOWN)
    raise RuntimeError(name)
# A: load-only BASIC program, then SAVE
shutil.copy("/tmp/t/fbml2.d64", "/tmp/t/fbmlw.d64")
v = mlstart("/tmp/t/fbmlw.d64")
goto(v, "joyst"); v.mkey(ord('8'), timeout=30)
time.sleep(6); v.wait_text("ready.", 60); time.sleep(3)
b=v.mem(0x2b,0x2e); print("A: TXTTAB=%04x VARTAB=%04x" % (b[0]+256*b[1], b[2]+256*b[3]))
v.keys(pet('save"j3",8\n')); time.sleep(8); v.wait_text("saving", 60); time.sleep(5)
v.show("A screen"); v.quit()
# B: run BASIC program
shutil.copy("/tmp/t/fbml2.d64", "/tmp/t/fbmlw.d64")
v = mlstart("/tmp/t/fbmlw.d64")
goto(v, "joyst"); v.mkey(RET, timeout=30); time.sleep(12)
print("B:", [l.strip() for l in v.screen()[0:9]])
v.quit()
# C: ML at $1000 overlaps the commander -> handoff with SYS
shutil.copy("/tmp/t/big2.d64", "/tmp/t/big9.d64")
shutil.copy("/tmp/t/fbml2.d64", "/tmp/t/fbmlw.d64")
v = mlstart("/tmp/t/fbmlw.d64", d9="/tmp/t/big9.d64", drive=ord('9'))
v.mkey(RIGHT); v.mkey(RIGHT); goto(v, "ml1000"); v.mkey(ord('7'), timeout=30); time.sleep(12)
print("C:", [l.strip() for l in v.screen()[0:10]], "row24:", v.screen()[24][:6])
b=v.mem(0x2b,0x2e); print("C: TXTTAB=%04x VARTAB=%04x" % (b[0]+256*b[1], b[2]+256*b[3]))
v.quit()
# D: exit with left arrow
shutil.copy("/tmp/t/fbml2.d64", "/tmp/t/fbmlw.d64")
v = mlstart("/tmp/t/fbmlw.d64")
v.mkey(0x5f, timeout=10) if False else None
v.enter(); v.cmd("> 0277 5f", wait=0.2); v.cmd("> 00c6 01", wait=0.2); v.go(); time.sleep(3)
print("D:", [l.strip() for l in v.screen()[0:3]], "repeat", v.mem(0x28a,0x28a)[0])
v.keys(pet('run\n')); time.sleep(3); v.idle(30)
print("D rerun:", v.screen()[1].strip())
v.quit()
