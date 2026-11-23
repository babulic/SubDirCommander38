import time, sys
sys.path.insert(0, "/tmp/t")
from vice import *
v = start("/tmp/t/fb38w.d64", d9="/tmp/t/big9.d64", drive=ord('9'))
v.key(RIGHT); v.key(RIGHT)
for i in range(14): v.key(DOWN)
print(v.screen()[15][:27])
v.key(ord('4'), at=5170); v.wait_line(4340, 60); time.sleep(0.3); v.keys([RET])
v.wait_line(4341, 30); time.sleep(0.3); v.keys(pet("8")+[RET])
v.wait_line(5170, 600); time.sleep(1)
print(v.screen()[2][:27])
v.quit()
