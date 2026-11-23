import time, sys
sys.path.insert(0, "/tmp/t")
from vice import *
v = start("/tmp/t/fb38.d64", d9="/tmp/t/big9.d64", drive=ord('9'))
def hl():
    rv = v.rev_rows(); sc = v.screen()
    rows = [r for r in range(2,24) if rv[r] > 10]
    return [(r, sc[r][:24].strip()) for r in rows]
print("start", hl())
for i in range(3): v.key(DOWN)
print("3 down", hl())
v.key(RIGHT); print("R", hl(), v.screen()[2][:20])
v.key(RIGHT); print("R", hl(), v.screen()[2][:20])
v.key(RIGHT); print("R (last page)", hl(), v.screen()[2][:20])
v.key(UP); print("UP", hl())
v.key(DOWN); v.key(DOWN); print("DOWN DOWN", hl())
v.key(LEFT); print("L", hl(), v.screen()[2][:20])
v.key(LEFT); print("L", hl(), v.screen()[2][:20])
v.key(LEFT); print("L (first page)", hl(), v.screen()[2][:20])
v.key(UP); print("UP at top", hl())
v.key(LEFT); print("L at P=0", hl())
for i in range(21): v.key(DOWN)
print("21 down", hl())
v.key(DOWN); print("22nd down flips", hl(), v.screen()[2][:20])
v.key(UP); print("up flips back", hl(), v.screen()[2][:20])
v.show("final")
v.shot("/tmp/t/s38_big.png")
v.quit()
