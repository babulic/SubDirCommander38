import time, sys
sys.path.insert(0, "/tmp/t")
from vice import *
v = mlstart("/tmp/t/fbmlw.d64")
v.show("ML start")
v.shot("/tmp/t/sml_start.png")
v.mkey(DOWN); v.mkey(DOWN); v.mkey(DOWN)
v.show("3 downs")
v.mkey(RIGHT); v.show("RIGHT")
v.mkey(LEFT); v.show("LEFT")
v.quit()
