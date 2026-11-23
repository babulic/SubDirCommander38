import time, sys
sys.path.insert(0, "/tmp/t")
from vice import *
v = start("/tmp/t/fb38w.d64", d9="/tmp/t/big9.d64", drive=ord('9'))
def copy(name, drive):
    v.key(ord('4'), at=5170)
    v.wait_line(4340, 60); time.sleep(0.3)
    v.keys(pet(name)+[RET])
    v.wait_line(4341, 30); time.sleep(0.3)
    v.keys(pet(drive)+[RET])
    t0=time.time()
    v.wait_line(5170, 600); time.sleep(1)
    return time.time()-t0
for i in range(5): v.key(DOWN)
print("cross copy file05 -> 8 took", copy("", "8"))
v.show("after cross copy file05 -> 8")
print("copy again took", copy("", "8"))
v.show("copy again -> expect 63 file exists")
v.shot("/tmp/t/s38_exists.png")
v.quit()
