# SubDirCommander 38

BASIC V2 disk commander for a stock Commodore 64 and a 1541 or SD2IEC.
This is the version kept apart from SubDirCommander 39. In prompts it is sub38.

| File | Kind | Size |
| --- | --- | --- |
| `basic/SubDirCommand.38.txt` | BASIC source | |
| `dist/SubDirCommand.38.prg` | tokenized program | 28 blocks |
| `dist/fb.d64` | frequently-used disk, `.37` replaced by `.38` | 21 blocks free |

Cross-drive copy pokes a small machine-code helper to address 828.
Line 4362 skips that poke when `PEEK(828)+PEEK(829)=169`, which is the
helper's first two bytes (`LDA #$00`) already in place.

## Run

```bash
petcat -w2 -o dist/SubDirCommand.38.prg -- basic/SubDirCommand.38.txt
x64sc -8 dist/fb.d64
```

`SubDirCommand.38` is already on `dist/fb.d64`. On the C64:

```text
LOAD"SUBDIRCOMMAND.38",8
RUN
```
