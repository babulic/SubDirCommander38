import time, sys
sys.path.insert(0, "/tmp/t")
from vice import *
v = start("/tmp/t/fb38w.d64", d9="/tmp/t/big9.d64", drive=ord('9'))
v.key(RIGHT); v.key(RIGHT)
for i in range(7): v.key(DOWN)
v.key(ord('7'), at=5170)
time.sleep(15)
v.show("7 on ml1000")
b=v.mem(0x2b,0x2e); print("TXTTAB=%04x VARTAB=%04x" % (b[0]+256*b[1], b[2]+256*b[3]))
print("key repeat $028a =", v.mem(0x28a,0x28a)[0])
v.quit()
