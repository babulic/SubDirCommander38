set -e
cd /tmp/t
cp fb.d64 fb38.d64
c1541 -attach fb38.d64 -delete "SubDirCommand.37" -write /agent/repos/tmp-f1df16a869fd94ff/dist/SubDirCommand.38.prg "SubDirCommand.38" >/dev/null 2>&1
cp fb38.d64 fbml.d64
c1541 -attach fbml.d64 -write /agent/repos/tmp-f1df16a869fd94ff/dist/%SubDirCommand38.prg "%SubDirCommand38" >/dev/null 2>&1
cp fb38.d64 fbml2.d64
c1541 -attach fbml2.d64 -delete "ex.simon's basic" -write /agent/repos/tmp-f1df16a869fd94ff/dist/%SubDirCommand38.prg "%SubDirCommand38" -write seq.bin "seqfile,s" >/dev/null 2>&1
