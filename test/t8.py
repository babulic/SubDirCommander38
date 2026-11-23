import time, sys
sys.path.insert(0, "/tmp/t")
from vice import *
v = start("/tmp/t/fb38w.d64", d9="/tmp/t/big9.d64")
for i in range(13): v.key(DOWN)
v.key(ord('8'), at=5170)
v.wait_text("ready.", 60); time.sleep(4)
v.show("after 8 on joyst")
b=v.mem(0x2b,0x2e); print("TXTTAB=%04x VARTAB=%04x" % (b[0]+256*b[1], b[2]+256*b[3]))
v.keys(pet('save"j2",8\n')); time.sleep(8); v.wait_text("ready.", 60)
v.keys(pet('list\n')); time.sleep(2)
v.show("save + list")
v.quit()
