import time, sys
sys.path.insert(0, "/tmp/t")
from vice import *
v = start("/tmp/t/fb38w.d64", d9="/tmp/t/big9.d64", drive=ord("9"), warp=False)
v.key(RIGHT); v.key(RIGHT)
for i in range(6): v.key(DOWN)
print("row before:", v.screen()[8][:27])
v.key(ord('8'), at=None)
for i in range(60):
    time.sleep(0.2)
    if v.line()==4487:
        print("during load:", v.screen()[8][:27]); break
v.wait_line(5170, 60); time.sleep(0.5)
print("after load:", v.screen()[8][:27])
v.quit()
