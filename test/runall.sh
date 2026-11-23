cd /tmp/t
bash mkdisks.sh
echo "### m2"; cp fbml.d64 fbmlw.d64; cp big2.d64 big9.d64; timeout 900 python3 m2.py 2>&1 | head -22
echo "### m4"; cp fbml2.d64 fbmlw.d64; cp full9.d64 full9w.d64; timeout 1200 python3 m4.py 2>&1 | tail -7
c1541 -attach full9w.d64 -dir | tail -1; c1541 -attach fbmlw.d64 -read "smallseq,s" ss3.out >/dev/null 2>&1; cmp ss3.out smallseq.bin && echo SEQ_OK
echo "### m5"; cp fbml2.d64 fbmlw.d64; cp big2.d64 big9.d64; timeout 1200 python3 m5.py 2>&1 | rg -v '^ ?[0-9]+[ *]\|'
c1541 -attach big9.d64 -read oxford ox3.prg >/dev/null 2>&1; python3 -c "
import sys; sys.path.insert(0,'/tmp/t')
from d64 import *
print('oxford identical:', D64('/tmp/t/fb.d64').read(b'OXFORD PASCAL')==open('/tmp/t/ox3.prg','rb').read())"
echo "### m6"; timeout 2400 python3 m6.py 2>&1 | rg -v '^ ?[0-9]+[ *]\|'
