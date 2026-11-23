import time, sys, shutil
sys.path.insert(0, "/tmp/t")
from vice import *
def hlrow(v):
    rv=v.rev_rows(); return [r for r in range(2,24) if rv[r]>10][0]
# ML version
shutil.copy("/tmp/t/fbml.d64", "/tmp/t/fbmlw.d64")
v = mlstart("/tmp/t/fbmlw.d64")
for i in range(9): v.mkey(DOWN)
print("ML on:", v.screen()[hlrow(v)][:27])
v.enter(); v.cmd("> 0277 0d", wait=0.2); v.cmd("> 00c6 01", wait=0.2); v.go(); time.sleep(25)
v.show("ML -> dc64"); v.shot("/tmp/t/sml_dc64.png"); v.quit()
# BASIC .38
shutil.copy("/tmp/t/fb38.d64", "/tmp/t/fb38w.d64")
v = start("/tmp/t/fb38w.d64")
for i in range(9): v.key(DOWN)
print("BASIC on:", v.screen()[11][:27])
v.key(RET, at=5170); time.sleep(25)
v.show("BASIC -> dc64"); v.quit()
