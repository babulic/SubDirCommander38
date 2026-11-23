# SubDir Commander 38 for the Commodore 64

A disk commander for a 1541 / 1541-II or SD2IEC drive on a stock C64. It
lists a directory, moves a cursor through it and runs, loads, renames,
copies, deletes and validates files. It comes in two versions with the same
screen and keys:

| File | Kind | Size |
| --- | --- | --- |
| `dist/SubDirCommand.38.prg` | BASIC V2 (from `SubDirCommand.37`) | 28 blocks |
| `dist/%SubDirCommand38.prg` | 6502 machine code, `SYS2061` stub | 20 blocks |
| `dist/fb.d64` | your `fb.d64`, `.37` replaced by `.38`, ML version added | 1 block free |

`.38` sits in the directory slot `.37` had. `%SubDirCommand38` is the last
entry. `%` is an ordinary character in a 1541 file name.

## Run it

In VICE on the Mac:

```bash
x64sc -8 dist/fb.d64
```

Then on the C64 (the names have capital S, D and C, so match them with `?`):

```text
LOAD"?UB?IR?OMMAND.38",8
RUN
```

```text
LOAD"%*",8
RUN
```

Give a second drive with `-9 other.d64` to try copying between drives.

## Keys

| Key | Action |
| --- | --- |
| CRSR up / down | one line |
| CRSR left / right | page up / page down (22 lines; on the first or last page: first or last entry) |
| 1 / F1 | choose the drive and list it |
| 2 / F2 | validate the disk and list again |
| 3 / F3 | rename |
| 4 / F4 | copy: name (RETURN = same name), then target drive (default: current) |
| 5 / F5 | show the start address of a PRG |
| 6 / F6 | delete (asks y/n; not locked files) |
| 7 / F7 / RETURN | run a program, enter a directory or disk image, run an `&` USR file in the drive |
| 8 / F8 | load a program without running it (directories and images open like 7) |
| ↑ | SD2IEC: one directory level up (`CD:←`) |
| ← | quit to BASIC |

The key panel on the right has a new `CRSR Keys:` block (`U/D LineUpDn`,
`L/R PageUpDn`); the old `CRSR MoveCur` line is gone.

Copy to another drive streams the file through the C64. PRG, SEQ and USR
files can be copied; REL files cannot. A failed copy (disk full, write
error, RUN/STOP) removes the partial file and validates the target so its
blocks come back. Copy on the same drive still uses the drive's own `C0:`.
Line 4362 skips poking the copy helper when `PEEK(828)+PEEK(829)=169`,
so a second copy does not read the helper out of `DATA` again.

## What changed from `.37`

- CRSR right no longer moves up a line. CRSR left/right now page.
- Copy asks for the target drive.
- **SAVE after loading a program saved the size of the commander.** `.37`
  ran `LOAD` inside the running program. BASIC treats that as chaining: it
  starts the new program but keeps the old end-of-program pointer
  (`VARTAB`, `$2D/$2E`), so `SAVE` wrote 22 blocks even for a 2-block
  program, and a program longer than the commander had its variables placed
  inside its own code. `.38` hands the program to BASIC the way you would
  type it: it prints `LOAD"name",8` on the screen, puts RETURN (plus `RUN` or
  `SYS address`) into the keyboard buffer and ends. BASIC then sets
  `VARTAB` itself. Before that it empties the BASIC program (zero link at
  `$0801`), because BASIC re-links the old program text after a direct
  `LOAD` and would otherwise overwrite machine code loaded into that area.
  Machine code that loads clear of the commander (for example at `$C000`)
  still loads from inside the program and returns afterwards.
- `8` (load) no longer starts BASIC programs; with chaining it always did.

## Review of `SubDirCommand.37`

The program is 169 lines (3000-5260). Line 3000 catches the restart after a
machine code `LOAD`; 3300-3820 are helpers (delay, screen frame, list
redraw, read-only check, wait for device); 4000-4160 read the drive status;
4200-4496 are the commands; 5000-5260 are set-up, directory reading and the
key loop. The directory is held in `M$()`/`S()` (up to 257 entries) and
shown in fixed pages of 22 entries.

Defects found and fixed in `.38`:

1. CRSR right moved the cursor up (line 5181).
2. `LOAD` in program mode kept the old `VARTAB` (see above). The `.37` file
   itself was saved that way: it carries 277 bytes of garbage after the end
   of the program.
3. `O%=-1` in line 5190 sets an integer variable no other line reads; `O`
   was meant, so after Validate the drive prompt came back.
4. Key repeat (`POKE650,128`) stayed on after quitting.
5. "Ran OK, press any key" left one letter of the line underneath.
6. "Load & run as Basic program from $2049" mixed hex notation and a decimal
   value; "Load from $" printed no address.
7. Copy on a full list could index past `M$(256)`.
8. The blocks-free line was shown as `27blocks free.` (no space).

Notes, not changed in the BASIC version: line 5110 assumes every directory
line is 32 bytes (true for 1541 and SD2IEC); typing over a two-digit default
in the drive prompt leaves the second digit; `UI` resets the drive on every
listing.

## Machine language version

`ml/sdc38.asm` (64tass). Same screen, keys and behaviour; the list is drawn
straight into screen RAM, so moving and paging are instant.

- Code `$0801-$1B1A`, work variables up to `$1C86`.
- Directory: RAM under the BASIC ROM, `$A000-$BFFF`, 32 bytes per entry,
  up to 242 entries.
- Copy buffer: `$1D00-$9FFF` (33 KB), so most files copy in one pass.
- Zero page `$4B-$72` holds the hot variables; BASIC's own bytes there
  (including its `JMP` at `$54`) are saved at start and put back on exit and
  while a loaded program runs.
- A program comes back to the commander only when it loads at or above
  `$1D00` and below `$D000`; everything else is handed to BASIC as above.
- The line editor in the prompts: first key replaces the default, DEL
  deletes, RETURN accepts, RUN/STOP cancels. RUN/STOP in the drive prompt
  quits.

## Build and test

```bash
tools/build.sh          # petcat, 64tass and c1541 -> dist/
```

`basic/SubDirCommand.38.txt` is the petcat listing of the BASIC program,
`basic/copyhelper.asm` the 138-byte copy routine it POKEs to `$033C`.
`original/` holds the extracted `.37` and the untouched `fb.d64`.

`test/` drives VICE through its remote monitor: `vice.py` types keys and
reads the screen, `t*.py` cover the BASIC version, `m*.py` the machine code
version (paging, every command, copies across drives including disk full and
file exists, loading BASIC and machine code, quitting). The scripts expect
their disk images in `/tmp/t` (`mkdisks.sh` builds them).
