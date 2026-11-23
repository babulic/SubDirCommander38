import time, sys
sys.path.insert(0, "/tmp/t")
from vice import *
v = start("/tmp/t/fb38.d64")
v.show("start .38"); v.shot("/tmp/t/s38_start.png")
v.key(RIGHT); v.show("RIGHT = page down")
v.key(RIGHT); v.show("RIGHT again on last page -> last entry")
v.key(UP); v.show("UP")
v.key(LEFT); v.show("LEFT = page up")
v.key(LEFT); v.show("LEFT again -> first entry")
for i in range(3): v.key(DOWN)
v.show("3 downs")
v.key(RIGHT); v.show("RIGHT from row 5 page1")
v.quit()
