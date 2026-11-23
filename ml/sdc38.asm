; %SubDirCommand38 - machine language SubDir Commander for the C64.
; Same screen, keys and commands as the BASIC SubDirCommand.38.
; Build: 64tass --cbm-prg -o sdc38ml.prg sdc38.asm
;
; Memory: code and work variables from $0801. Directory entries live in the
; RAM under the BASIC ROM ($A000-$BFFF, 32 bytes each). The free BASIC RAM
; between the end of the code and $A000 is the buffer for drive-to-drive
; copies. Programs are started the way a user would type LOAD and RUN, so
; BASIC sets its own pointers.

        .cpu "6502"

        .enc "pet"
        .cdef " @", $20
        .cdef "az", $41
        .cdef "AZ", $c1
        .cdef "[[", $5b
        .cdef "]]", $5d
        .cdef "^^", $5e
        .cdef "__", $5f

; KERNAL
READST  = $ffb7
SETLFS  = $ffba
SETNAM  = $ffbd
OPEN    = $ffc0
CLOSE   = $ffc3
CHKIN   = $ffc6
CHKOUT  = $ffc9
CLRCHN  = $ffcc
CHRIN   = $ffcf
CHROUT  = $ffd2
LOAD    = $ffd5
STOP    = $ffe1
GETIN   = $ffe4
LISTEN  = $ffb1
SECOND  = $ff93
UNLSN   = $ffae

STATUS  = $90
JIFFY   = $a2
FA      = $ba
NDX     = $c6
KEYD    = $0277
RPTFLG  = $028a
COLOR   = $0286
TXTTAB  = $2b

SCR     = $0400
COLRAM  = $d800

C_BLUE  = 6
C_LBLU  = 14
C_GRY2  = 12
C_CYAN  = 3
C_WHT   = 1

LISTW   = 27            ; width of the list column
PANELC  = 27            ; first column of the key panel
ROW0    = 2             ; first list row
NROWS   = 22
DIRBUF  = $a000
ENTSZ   = 32
TXTMAX  = 29            ; directory text bytes kept per entry
MAXENT  = 242           ; 11 pages of 22, an index fits in a byte
BUFEND  = $a0           ; copy buffer ends below $A000

; zero page: BASIC temporaries and $FB-$FE, free while we run
zp1     = $fb
zp2     = $fd
scr     = $22
col     = $24
zp3     = $26

; --------------------------------------------------------------------------
        * = $0801
        .word basend, 2026
        .null $9e, format("%d", start)
basend  .word 0

start   tsx
        stx savesp
        ldx #zpend-ZPVARS-1     ; keep BASIC's copy (its JMP at $54 lives here)
-       lda ZPVARS,x
        sta bsave,x
        dex
        bpl -
        jsr scrinit
        lda FA
        cmp #8
        bcc defdrv
        cmp #12
        bcc setdrv
defdrv  lda #8
setdrv  sta dev
        lda #$ff
        sta last

; ---------------------------------------------------------------- drive menu
seldrv  jsr closeall
        jsr cls
        lda #1
        sta row
        lda #<s_seldrv
        ldx #>s_seldrv
        jsr msgrow
        lda dev
        jsr numfield
        lda #15
        sta incol
        jsr lineinput
        bcc +
        jmp exitapp
+       jsr parsenum
        cmp #8
        bcc seldef
        cmp #12
        bcs seldef
        sta dev
        jmp relist
seldef  lda #8
        sta dev
        jmp seldrv

; ------------------------------------------------------- read and show list
relist  lda #0
        sta oslen
        jsr drawframe
        jsr getos
        bcs fatal
        jsr drawrow0
        jsr readdir
        bcs fatal
        lda #0
        sta pos
        sta top
        jsr drawlist
        jmp main

fatal   jsr showerr
        jmp seldrv

; ------------------------------------------------------------- key dispatch
main    jsr getkey
        cmp #$85                ; F1..F8 act like the digit keys
        bcc +
        cmp #$8d
        bcs +
        tax
        lda fkeys-$85,x
+       ldx #0
-       cmp keytab,x
        beq +
        inx
        inx
        inx
        ldy keytab,x
        bne -
        jmp main
+       lda keytab+2,x
        pha
        lda keytab+1,x
        pha
        rts

keytab  .byte $11
        .word kdown-1
        .byte $91
        .word kup-1
        .byte $1d
        .word kright-1
        .byte $9d
        .word kleft-1
        .byte "1"
        .word seldrv-1
        .byte "2"
        .word cvalid-1
        .byte "3"
        .word crename-1
        .byte "4"
        .word ccopy-1
        .byte "5"
        .word cstart-1
        .byte "6"
        .word cdelete-1
        .byte "7"
        .word crun-1
        .byte $0d
        .word crun-1
        .byte "8"
        .word cload-1
        .byte $5e
        .word cdup-1
        .byte $5f
        .word exitapp-1
        .byte 0

fkeys   .text "13572468"

; ------------------------------------------------------------- cursor keys
kdown   jsr haslist
        lda pos
        cmp last
        bcs nomove
        sta oldpos
        inc pos
        lda pos
        sec
        sbc top
        cmp #NROWS
        bcc movehl
        lda top
        clc
        adc #NROWS
        sta top
        jmp redraw

kup     jsr haslist
        lda pos
        beq nomove
        sta oldpos
        dec pos
        lda pos
        cmp top
        bcs movehl
        lda top
        sec
        sbc #NROWS
        sta top
        jmp redraw

kright  jsr haslist
        lda top
        clc
        adc #NROWS
        sta zp3
        lda last
        cmp zp3
        bcc tolast
        lda zp3
        sta top
        lda pos
        clc
        adc #NROWS
        bcs pdlast
        cmp last
        bcc pdset
pdlast  lda last
pdset   sta pos
        jmp redraw
tolast  lda last
        jmp jumpto

kleft   jsr haslist
        lda top
        beq tofirst
        sec
        sbc #NROWS
        sta top
        lda pos
        sec
        sbc #NROWS
        sta pos
        jmp redraw
tofirst lda #0
jumpto  cmp pos
        beq nomove
        ldx pos
        stx oldpos
        sta pos
movehl  lda oldpos
        jsr drawent
        lda pos
        jsr drawent
nomove  jmp main

redraw  jsr drawlist
        jmp main

; Return to main (dropping the caller) when no directory is loaded.
haslist ldx last
        inx
        bne +
        pla
        pla
        jmp main
+       rts

; -------------------------------------------------------------- ^, validate
cdup    jsr cmdi
        .null "cd:_"
        jmp dosrelist

cvalid  jsr haslist
        lda bfree+1
        cmp #>3161
        bcc +
        bne nomove
        lda bfree
        cmp #<3161
        bcs nomove
+       jsr msgi
        .null "Validating disk ..."
        jsr cmdi
        .null "v0"
dosrelist
        jsr doscmd
        bcs +
        jsr waitdev
        bcs +
        jmp relist
+       jmp fatal

; ------------------------------------------------------------- 5 start adr
cstart  jsr parseprg
        bcs nomove
        lda ro
        bne nomove
        lda type
        cmp #"p"
        bne nomove
        jsr getstart
        bcs fatalj
        jsr msgi
        .null "Start adr.: "
        jsr decsa
        jmp main
fatalj  jmp fatal

; --------------------------------------------------------------- 3 rename
crename jsr parsefile
        bcs restore
        lda ro
        bne restore
        jsr msgi
        .null "Rename to:"
        lda #11
        jsr namefield
        bcs restore
        jsr takename
        lda newlen
        beq restore
        jsr samename
        bcs restore
        jsr msgi
        .null "Renaming ..."
        jsr cmdi
        .null "r0:"
        jsr cmdnew
        lda #"="
        jsr cmdchr
        jsr cmdname
        jsr doscmd
        bcs fatalj
        jsr waitdev
        bcs fatalj
        lda pos
        jsr getent
        jsr newtext
        lda pos
        jsr putent
restore lda pos
        jsr drawent
        jmp main

; --------------------------------------------------------------- 6 delete
cdelete jsr parsefile
        bcs restore
        lda ro
        ora locked
        bne restore
        jsr msgi
        .null "Are you sure? y/n"
        jsr getkey
        and #$7f
        cmp #"y"
        bne restore
        jsr cmdi
        .null "s0:"
        jsr cmdname
        jsr doscmd
        bcs fatalj
        jsr waitdev
        bcs fatalj
        lda pos
        jsr getent
        lda ent
        clc
        adc bfree
        sta bfree
        lda ent+1
        adc bfree+1
        sta bfree+1
        lda #0
        sta ent
        sta ent+1
        lda #25
        sta ent+2
        ldx #24
-       lda s_deleted,x
        sta ent+3,x
        dex
        bpl -
        lda pos
        jsr putent
        jsr setbfree
        jmp redraw

; ----------------------------------------------------------------- 4 copy
ccopy   jsr parsefile
        bcs restore
        lda ro
        bne restore
        lda blocks
        ora blocks+1
        beq restore
        jsr msgi
        .null "Copy to:"
        lda #9
        jsr namefield
        bcs restore
        jsr takename
        jsr msgi
        .null "Target drive:"
        lda dev
        jsr numfield
        lda #14
        sta incol
        jsr lineinput
        bcs restore2
        jsr parsenum
        cmp #8
        bcc restore2
        cmp #12
        bcs restore2
        sta tdev
        lda newlen
        bne +
        jsr oldtonew
+       lda tdev
        cmp dev
        bne xdev
        jsr samename
        bcs restore2
        jsr msgi
        .null "Copying ..."
        jsr cmdi
        .null "c0:"
        jsr cmdnew
        lda #"="
        jsr cmdchr
        jsr cmdname
        jsr doscmd
        bcs fatalc
        jsr waitdev
        bcs fatalc
        lda last
        cmp #MAXENT-1
        bcs restore2
        jsr getent              ; blocks free line moves down one
        inc last
        lda last
        jsr putent
        lda pos
        jsr getent
        jsr newtext
        ldx last
        dex
        txa
        jsr putent
        lda bfree
        sec
        sbc blocks
        sta bfree
        lda bfree+1
        sbc blocks+1
        sta bfree+1
        jsr setbfree
        jmp redraw
restore2
        jmp restore
fatalc  jmp fatal

xdev    jsr xcopy
        bcs fatalc
        jmp restore

; --------------------------------------------------------- 7 / 8 run, load
crun    lda #1
        .byte $2c
cload   lda #0
        sta runflag
        jsr parseprg
        bcc +
        jmp main
+       lda isamp
        beq notamp
        lda type
        cmp #"u"
        bne notamp
        lda #0                  ; "&name" runs a USR file inside the drive
        sta cmdlen
        jsr cmdname
        jsr opencmd             ; no status read: the utility owns the drive
        bcs ampbad
        jsr waitdev
        php
        jsr closeall
        plp
        bcs ampbad
        jmp relist
ampbad  jmp fatal
notamp  lda ro
        beq +
        jsr cmdi
        .null "cd:"
        jsr cmdname
        jmp dosrelist
+       jsr getstart
        bcc +
        jmp fatal
+       lda #0
        sta ldml
        lda saddr
        cmp #$01
        bne +
        lda saddr+1
        cmp #$08
        bne +
        jmp handoff
+       inc ldml
        lda blocks+1            ; end estimate = start + blocks * 254
        bne slow
        lda #0
        sta zp1+1
        lda blocks
        asl
        sta zp1
        rol zp1+1
        lda #0
        sec
        sbc zp1
        sta zp2
        lda blocks
        sbc zp1+1
        sta zp2+1
        lda zp2
        clc
        adc saddr
        sta eaddr
        lda zp2+1
        adc saddr+1
        sta eaddr+1
        bcs slow
        lda saddr+1             ; come back only when clear of code and I/O
        cmp #>bufstart
        bcc slow
        lda eaddr+1
        cmp #$d0
        bcc direct
        bne slow
        lda eaddr
        beq direct
slow    jmp handoff

; ML that stays clear of the commander is loaded here and may come back.
direct  jsr msgi
        .null "Load from "
        jsr decsa
        jsr setname
        lda #1
        ldx dev
        ldy #1
        jsr SETLFS
        lda #0
        jsr LOAD
        bcc +
        jsr kerr
        jmp fatal
+       stx eaddr
        sty eaddr+1
        jsr READST
        and #$bf
        beq +
        jsr sterr
        jmp fatal
+       lda runflag
        beq ldok
        ldx #zpend-ZPVARS-1
-       lda ZPVARS,x
        sta zsave,x
        dex
        bpl -
        jsr zpbasic
        jsr callml
        ldx #zpend-ZPVARS-1
-       lda zsave,x
        sta ZPVARS,x
        dex
        bpl -
        jsr scrinit
        jsr msgi
        .null "Ran OK, press any key ..."
        jsr getkey
        jsr dirhit
        bcs relistj
        jsr drawframe
        jsr drawhdr
        jmp redraw
ldok    jsr dirhit
        bcs relistj
        jsr msgi
        .null "Loaded OK, end $"
        lda eaddr
        ldx eaddr+1
        jsr hex16
        jmp main
relistj jmp relist

; Carry set when the loaded range touched the directory under BASIC ROM.
dirhit  lda eaddr+1
        cmp #$a0
        bcc dhno
        lda saddr+1
        cmp #$c0
        bcs dhno
        sec
        rts
dhno    clc
        rts

callml  lda saddr
        sec
        sbc #1
        tax
        lda saddr+1
        sbc #0
        pha
        txa
        pha
        lda #$37
        sta $01
        rts

; Hand the program to BASIC: LOAD"name",dev[,1] on screen, RETURN plus RUN
; or SYS in the keyboard buffer, an empty BASIC program, back to READY.
handoff jsr closeall
        lda #0
        sta RPTFLG
        lda #$80
        sta hoff
        ldy #1                  ; KEYD+0 is the RETURN for the LOAD line
        lda runflag
        beq hokb
        ldx #0
        lda ldml
        beq +
        ldx #3
+       lda #3
        sta kcount
-       lda s_rs,x
        sta KEYD,y
        inx
        iny
        dec kcount
        bne -
        lda ldml
        beq +
        sty kcount
        lda saddr
        ldx saddr+1
        jsr num2dec
        ldy kcount
        ldx #0
-       lda decbuf,x
        sta KEYD,y
        iny
        inx
        cpx declen
        bne -
+       lda #$0d
        sta KEYD,y
        iny
hokb    sty kcount
        lda #$0d
        sta KEYD
        lda #C_WHT
        sta COLOR
        lda #$93
        jsr CHROUT
        jsr stri
        .null "Load"
        lda runflag
        beq +
        jsr stri
        .null " & "
        ldy #1
-       lda KEYD,y
        cmp #$0d
        beq +
        jsr CHROUT
        iny
        bne -
+       lda #C_LBLU
        sta COLOR
        jsr stri
        .null $0d, $11, "load", $22
        ldy #0
-       cpy namelen
        beq +
        lda namebuf,y
        jsr CHROUT
        iny
        bne -
+       jsr stri
        .null $22, ","
        lda dev
        ldx #0
        jsr decout
        lda ldml
        beq +
        jsr stri
        .null ",1"
+       lda #$13
        jsr CHROUT
        lda kcount
        sta NDX
        ldy #0
        tya
        sta (TXTTAB),y
        iny
        sta (TXTTAB),y
        jmp leave

; ------------------------------------------------------------------ exit
exitapp lda #0
        sta RPTFLG
        lda #C_LBLU
        sta COLOR
        lda #$93
        jsr CHROUT
leave   jsr closeall
        lda #$37
        sta $01
        jsr zpbasic
        ldx savesp
        txs
        rts

; Put BASIC's zero page bytes back.
zpbasic ldx #zpend-ZPVARS-1
-       lda bsave,x
        sta ZPVARS,x
        dex
        bpl -
        rts

; ========================================================== drive commands
; Probe the device in A. Carry set when it does not answer.
probe   pha
        lda #0
        sta STATUS
        pla
        jsr LISTEN
        lda #$6f
        jsr SECOND
        jsr UNLSN
        lda STATUS
        asl
        rts

; Wait until the current drive answers again (after UI, CD, copy...).
waitdev lda #13
        sta tries
-       lda dev
        jsr probe
        bcc +
        lda #20
        jsr delay
        dec tries
        bne -
        jmp devnp
+       rts

delay   clc
        adc JIFFY
-       cmp JIFFY
        bne -
        rts

; Reset the drive with UI, keep its name, initialize CBM type drives.
getos   jsr cmdi
        .null "ui"
        jsr opencmd
        bcs gosx
        lda #30
        jsr delay
        ldx #15
        jsr readstat
        bcs gosc
        ldx #0                  ; message field after the first comma
-       lda statbuf,x
        beq gosf
        inx
        cmp #","
        bne -
gosf    ldy #0
-       lda statbuf,x
        beq +
        cmp #","
        beq +
        sta osbuf,y
        inx
        iny
        cpy #LISTW
        bne -
+       sty oslen
        lda #" "
-       cpy #LISTW
        beq +
        sta osbuf,y
        iny
        bne -
+       ldx #2
-       lda osbuf
        cmp cbmtab,x
        bne +
        lda osbuf+1
        cmp cbmtab+3,x
        bne +
        lda osbuf+2
        cmp cbmtab+6,x
        beq goinit
+       dex
        bpl -
        bmi gosok
goinit  ldx #15
        jsr CHKOUT
        lda #"i"
        jsr CHROUT
        lda #"0"
        jsr CHROUT
        lda #$0d
        jsr CHROUT
        jsr CLRCHN
gosok   lda #15
        jsr CLOSE
        jsr CLRCHN
        jmp waitdev
gosc    lda #15
        jsr CLOSE
        jsr CLRCHN
        sec
gosx    rts

cbmtab  .text "ccj"
        .text "boi"
        .text "mpf"

; Send cmdbuf on the command channel and read the reply.
; Carry set on a DOS error (>= 2) or I/O error, message in statbuf.
doscmd  jsr opencmd
        bcs +
        ldx #15
        jsr readstat
        php
        lda #15
        jsr CLOSE
        jsr CLRCHN
        plp
        bcs +
        lda errnum
        cmp #2
+       rts

opencmd lda dev
        jsr probe
        bcc +
        jmp devnp
+       lda #15
        ldx dev
        ldy #15
        jmp opfile

; Read the status line of the command channel open as file X.
readstat
        jsr CHKIN
        bcc +
        jsr CLRCHN
        jmp kerr
+       ldy #0
        sty STATUS
rs1     jsr CHRIN
        cmp #$0d
        beq rs2
        cpy #40
        bcs +
        sta statbuf,y
        iny
+       lda STATUS
        beq rs1
rs2     lda #0
        sta statbuf,y
        lda STATUS
        pha
        jsr CLRCHN
        pla
        and #$83
        beq +
        sta STATUS
        jmp sterr
+       lda statbuf
        and #$0f
        asl
        sta errnum
        asl
        asl
        adc errnum
        sta errnum
        lda statbuf+1
        and #$0f
        adc errnum
        sta errnum
        clc
        rts

; ---------------------------------------------------------- start address
; Open the selected PRG and read its load address. Carry set on error.
getstart
        lda namelen
        sta cmdlen
        ldx #15
-       lda namebuf,x
        sta cmdbuf,x
        dex
        bpl -
        lda #1
        ldx dev
        ldy #0
        jsr opfile
        bcs gsx
        ldx #1
        jsr CHKIN
        lda #0
        sta STATUS
        jsr CHRIN
        sta saddr
        jsr CHRIN
        sta saddr+1
        lda STATUS
        pha
        jsr CLRCHN
        lda #1
        jsr CLOSE
        pla
        and #$b2
        beq +
        sta STATUS
        jmp sterr
+       clc
gsx     rts

; Filename of the selected entry for SETNAM.
setname lda namelen
        ldx #<namebuf
        ldy #>namebuf
        jmp SETNAM

; ----------------------------------------------------------- directory read
readdir lda #$ff
        sta last
        sta pos
        lda #0
        sta top
        sta hdrlen
        jsr cmdi
        .null "$0"
        lda #2
        ldx dev
        ldy #0
        jsr opfile
        bcc +
        rts
+       ldx #2
        jsr CHKIN
        lda #0
        sta STATUS
        sta eof
        jsr rdb
        jsr rdb
        lda #1
        sta first
rdline  lda eof
        bne rddone
        jsr rdb
        sta zp3
        jsr rdb
        ora zp3
        beq rddone
        lda eof
        bne rddone
        jsr rdb
        sta ent
        jsr rdb
        sta ent+1
        ldy #0
rdtxt   jsr rdb
        beq rdtend
        cpy #TXTMAX
        bcs +
        sta ent+3,y
        iny
+       lda eof
        beq rdtxt
rdtend  sty ent+2
        lda first
        beq rdent
        lda #0
        sta first
        tay
        tax
-       cpy ent+2               ; header, without its reverse-on code
        beq +
        lda ent+3,y
        iny
        cmp #$12
        beq -
        sta hdr,x
        inx
        bne -
+       stx hdrlen
        jsr drawhdr
        jmp rdline
rdent   ldx last
        inx
        cpx #MAXENT
        bcs rdline
        stx last
        txa
        jsr putent
        lda last
        cmp #NROWS
        bcs rdline
        jsr drawent
        jmp rdline
rddone  lda STATUS
        sta zp3
        jsr CLRCHN
        lda #2
        jsr CLOSE
        lda last
        cmp #$ff
        bne +
        lda zp3
        and #$83
        sta STATUS
        jmp sterr
+       jsr getent
        lda ent
        sta bfree
        lda ent+1
        sta bfree+1
        lda ent+3
        cmp #" "
        beq +
        jsr setbfree            ; one space after the number, as LIST shows it
+       clc
        rts

; Read a byte, flag end of file. Z reflects the byte.
rdb     jsr CHRIN
        pha
        lda STATUS
        beq +
        lda #1
        sta eof
+       pla
        rts

; Rewrite the blocks free line (index last) from bfree.
setbfree
        lda bfree
        sta ent
        lda bfree+1
        sta ent+1
        ldy #0
-       lda s_bfree,y
        beq +
        sta ent+3,y
        iny
        bne -
+       sty ent+2
        lda last
        jmp putent

; --------------------------------------------------------- entry storage
; Copy entry A from the RAM under BASIC ROM to ent.
getent  jsr entaddr
        ldy #ENTSZ-1
        lda #$36
        sta $01
-       lda (zp1),y
        sta ent,y
        dey
        bpl -
        lda #$37
        sta $01
        rts

putent  jsr entaddr
        ldy #ENTSZ-1
-       lda ent,y
        sta (zp1),y
        dey
        bpl -
        rts

entaddr pha
        lsr
        lsr
        lsr
        clc
        adc #>DIRBUF
        sta zp1+1
        pla
        pha
        asl
        asl
        asl
        asl
        asl
        sta zp1
        pla
        rts

; Parse the selected entry: name, type, flags. Carry set if no file name.
; parseprg also wants something runnable: a dir, an image, an & file or a
; PRG with blocks.
parsefile
        lda #0
        .byte $2c
parseprg
        lda #1
        sta spmode
        ldx last
        inx
        beq pfno
        lda pos
        jsr getent
        lda ent
        sta blocks
        lda ent+1
        sta blocks+1
        lda #0
        sta ro
        sta locked
        sta isamp
        sta namelen
        ldx #0
-       cpx ent+2
        beq pfno
        lda ent+3,x
        inx
        cmp #$22
        bne -
        stx qpos
        ldy #0
-       cpx ent+2
        beq pfno
        lda ent+3,x
        inx
        cmp #$22
        beq +
        cpy #16
        bcs -
        sta namebuf,y
        iny
        bne -
+       sty namelen
        tya
        beq pfno
        lda namebuf
        cmp #"&"
        bne +
        inc isamp
+       ldx qpos                ; type at name+18, lock flag at name+21
        ldy #0
-       lda ent+3+18,x
        sta type,y
        inx
        iny
        cpy #3
        bne -
        lda ent+3+18,x
        cmp #"<"
        bne +
        inc locked
+       lda type
        cmp #"d"
        bne +
        lda type+1
        cmp #"i"
        bne +
        inc ro
+       jsr imgext
        lda spmode
        beq pfok
        lda isamp
        ora ro
        bne pfok
        lda type
        cmp #"p"
        bne pfno
        lda blocks
        ora blocks+1
        beq pfno
pfok    clc
        rts
pfno    sec
        rts

; Disk images (.d64 .g64 .d81 .t64) open with CD like directories.
imgext  ldx namelen
        cpx #5
        bcc imgx
        lda namebuf-4,x
        cmp #"."
        bne imgx
        ldy #3
-       lda namebuf-3,x
        and #$7f
        cmp imgtab,y
        bne +
        lda namebuf-2,x
        and #$7f
        cmp imgtab+4,y
        bne +
        lda namebuf-1,x
        and #$7f
        cmp imgtab+8,y
        bne +
        inc ro
        rts
+       dey
        bpl -
imgx    rts

imgtab  .text "dgdt"
        .text "6686"
        .text "4414"

; Directory text of a renamed/copied entry in ent: same layout, newname
; padded to the 16 character name field.
newtext ldx qpos
        ldy #0
-       cpy newlen
        beq +
        lda newname,y
        sta ent+3,x
        inx
        iny
        bne -
+       lda #$22
        sta ent+3,x
        inx
        lda #" "
-       cpy #16
        beq +
        sta ent+3,x
        inx
        iny
        bne -
+       rts

; Typed name (inbuf) -> newname.
takename
        ldx #15
-       lda inbuf,x
        sta newname,x
        dex
        bpl -
        lda inlen
        sta newlen
        rts

; Carry set when newname equals the selected name.
samename
        lda newlen
        cmp namelen
        bne +
        tax
-       dex
        bmi same
        lda newname,x
        cmp namebuf,x
        beq -
+       clc
        rts
same    sec
        rts

oldtonew
        ldx #15
-       lda namebuf,x
        sta newname,x
        dex
        bpl -
        lda namelen
        sta newlen
        rts

; ------------------------------------------------------ inline texts
; cmdi, stri and erri take the 0-terminated text that follows the JSR.
; cmdi: text -> cmdbuf. stri: print it after the last message.
; erri: text -> statbuf, then return to our caller's caller with carry set.
cmdi    pla
        sta zp2
        pla
        sta zp2+1
        ldy #0
-       iny
        lda (zp2),y
        sta cmdbuf-1,y
        bne -
        dey
        sty cmdlen
        iny
inlret  tya
        clc
        adc zp2
        tax
        lda zp2+1
        adc #0
        pha
        txa
        pha
        rts

stri    pla
        sta zp2
        pla
        sta zp2+1
        ldy #0
-       iny
        lda (zp2),y
        beq inlret
        jsr chrout2
        jmp -

erri    pla
        sta zp2
        pla
        sta zp2+1
        ldy #0
-       iny
        lda (zp2),y
        sta statbuf-1,y
        bne -
        sec
        rts

; ------------------------------------------------------ command buffer
; cmdset: A/X = text, Y = length. cmdchr appends A.
cmdset  sta zp2
        stx zp2+1
        sty cmdlen
        dey
-       lda (zp2),y
        sta cmdbuf,y
        dey
        bpl -
        rts

cmdchr  ldx cmdlen
        sta cmdbuf,x
        inc cmdlen
        rts

cmdname ldy #0
-       cpy namelen
        beq +
        lda namebuf,y
        jsr cmdchr
        iny
        bne -
+       rts

cmdnew  ldy #0
-       cpy newlen
        beq +
        lda newname,y
        jsr cmdchr
        iny
        bne -
+       rts

cmdapp  sta zp2
        stx zp2+1
        ldy #0
-       lda (zp2),y
        beq +
        jsr cmdchr
        iny
        bne -
+       rts

; Open file A on device X, secondary Y, with cmdbuf/cmdlen as the name.
opfile  jsr SETLFS
        lda cmdlen
        ldx #<cmdbuf
        ldy #>cmdbuf
        jsr SETNAM
        jsr OPEN
        bcc +
        jmp kerr
+       rts

; ====================================================== drive to drive copy
; Copies the selected PRG/SEQ/USR file from dev to tdev as newname,
; through the free BASIC RAM. Carry set with a message on failure.
xcopy   lda type
        ldx #2
-       cmp okty,x
        beq +
        dex
        bpl -
        jsr erri
        .null "Only prg/seq/usr files !"
+       lda tdev
        jsr probe
        bcc +
        jmp devnp
+       jsr msgi
        .null "Copying to drive "
        lda tdev
        ldx #0
        jsr decout
        jsr stri
        .null " ..."
        lda #0                  ; source: 1 = command channel, 2 = file
        sta cmdlen
        lda #1
        ldx dev
        ldy #15
        jsr opfile
        bcs xfail
        jsr xname
        jsr cmdname
        lda #<s_cr
        ldx #>s_cr
        jsr xtype
        lda #2
        ldx dev
        ldy #2
        jsr opfile
        bcs xfail
        ldx #1
        jsr readstat
        bcs xfail
        lda errnum
        cmp #2
        bcs xfail
        lda #0                  ; target: 4 = command channel, 3 = file
        sta cmdlen
        lda #4
        ldx tdev
        ldy #15
        jsr opfile
        bcs xfail
        jsr xname
        jsr cmdnew
        lda #<s_cw
        ldx #>s_cw
        jsr xtype
        lda #3
        ldx tdev
        ldy #3
        jsr opfile
        bcs xfail
        ldx #4
        jsr readstat
        bcs xfail
        lda errnum
        cmp #2
        bcs xfail
        jsr xloop
        ror xbad                ; bit 7: transfer failed
        lda #3
        jsr CLOSE
        ldx #4
        jsr readstat
        bcs +
        lda errnum
        cmp #2
+       bcs xclean              ; DOS error after the write, message kept
        bit xbad
        bpl xok
        lda #<e_abort
        ldx #>e_abort
        jsr seterr
xclean  jsr xname               ; remove the partial file, free its blocks
        lda #"s"
        sta cmdbuf
        jsr cmdnew
        jsr xsend
        jsr cmdi
        .null "v0"
        jsr xsend
        ldx #4
        jsr CHKIN
-       jsr CHRIN
        ldx STATUS
        bne xfail
        cmp #$0d
        bne -
xfail   jsr closeall
        sec
        rts
xok     jsr closeall
        clc
        rts

xname   jsr cmdi
        .null "0:"
        rts

; Send cmdbuf as one command on the target command channel (file 4).
xsend   ldx #4
        jsr CHKOUT
        ldy #0
-       lda cmdbuf,y
        jsr CHROUT
        iny
        cpy cmdlen
        bne -
        lda #$0d
        jsr CHROUT
        jmp CLRCHN

xtype   sta zp2
        stx zp2+1
        lda #","
        jsr cmdchr
        lda type
        jsr cmdchr
        ldy #0
-       lda (zp2),y
        beq +
        jsr cmdchr
        iny
        bne -
+       rts

okty    .text "psu"

; Move file 2 to file 3 in chunks. Carry set on error or RUN/STOP.
xloop   lda #0
        sta eof
        sta xbad
xfill   jsr CLRCHN
        lda #0
        sta STATUS
        ldx #2
        jsr CHKIN
        bcs xerr
        lda #<bufstart
        sta zp1
        lda #>bufstart
        sta zp1+1
        ldy #0
xrd     jsr CHRIN
        sta (zp1),y
        lda STATUS
        bne xst
        iny
        bne xrd
        jsr STOP
        beq xerr
        inc zp1+1
        lda zp1+1
        cmp #BUFEND
        bne xrd
        beq xflush
xst     and #$bf
        bne xerr
        inc eof
        iny
        bne xflush
        inc zp1+1
xflush  sty zp1
        jsr CLRCHN
        lda #0
        sta STATUS
        ldx #3
        jsr CHKOUT
        bcs xerr
        lda #<bufstart
        sta zp2
        lda #>bufstart
        sta zp2+1
        ldy #0
xwl     lda zp2+1
        cmp zp1+1
        bne +
        cpy zp1
        beq xwd
+       lda (zp2),y
        jsr CHROUT
        iny
        bne xwl
        inc zp2+1
        bne xwl
xwd     lda STATUS
        bne xerr
        lda eof
        beq xfill
        jsr CLRCHN
        clc
        rts
xerr    jsr CLRCHN
        sec
        rts

closeall
        lda #3
        jsr CLOSE
        lda #2
        jsr CLOSE
        lda #4
        jsr CLOSE
        lda #1
        jsr CLOSE
        lda #15
        jsr CLOSE
        jmp CLRCHN

; ================================================================ errors
; Messages for showerr: statbuf holds the text, carry set on return.
devnp   lda #<e_devnp
        ldx #>e_devnp
seterr  sta zp2
        stx zp2+1
        ldy #0
-       lda (zp2),y
        sta statbuf,y
        beq +
        iny
        bne -
+       sec
        rts

kerr    cmp #5
        beq devnp
        jsr erri
        .null "I/O error !"

sterr   lda STATUS
        bmi devnp
        and #$02
        beq +
        jsr erri
        .null "Timeout !"
+       lda #<e_rd
        ldx #>e_rd
        jmp seterr

; Show statbuf on rows 2 and 3 and wait for a key.
showerr jsr closeall
        lda #ROW0
        jsr rowptr
        lda #" "
        sta line
        ldx #0
-       lda statbuf,x
        beq +
        sta line+1,x
        inx
        cpx #LISTW-1
        bne -
+       inx
        jsr padline
        lda #C_WHT
        ldx #$80
        jsr putline
        lda #ROW0+1
        jsr rowptr
        ldx #LISTW-1
-       lda s_press,x
        sta line,x
        dex
        bpl -
        lda #C_WHT
        ldx #$80
        jsr putline
        jmp getkey

; ================================================================ screen
scrinit lda #C_BLUE
        sta $d021
        lda #C_LBLU
        sta $d020
        sta COLOR
        lda #$37
        sta $01
        lda #0
        sta hoff
        jsr CLRCHN
        lda #$0e
        jsr CHROUT
        lda #$80
        sta RPTFLG
        rts

cls     ldx #0
-       lda #" "
        sta SCR,x
        sta SCR+$100,x
        sta SCR+$200,x
        sta SCR+$2e8,x
        lda #C_LBLU
        sta COLRAM,x
        sta COLRAM+$100,x
        sta COLRAM+$200,x
        sta COLRAM+$2e8,x
        inx
        bne -
        rts

; Clear the screen and draw row 0 and the key panel.
drawframe
        jsr cls
        jsr drawrow0
        lda #<panel
        sta zp2
        lda #>panel
        sta zp2+1
dfnext  ldy #0
        lda (zp2),y
        bmi dfend
        jsr rowptr
        ldy #1
        lda (zp2),y
        sta rvs
        lda zp2
        clc
        adc #2
        sta zp2
        bcc +
        inc zp2+1
+       lda #PANELC
        sta xcol
        lda #C_GRY2
        sta tcol
        jsr putrich
        jmp dfnext
dfend   rts

; Row 0: drive name from UI in reverse grey, or the title.
drawrow0
        lda #0
        jsr rowptr
        ldx #LISTW-1
        lda oslen
        beq dr0t
-       lda osbuf,x
        sta line,x
        dex
        bpl -
        bmi dr0p
dr0t    lda s_title,x
        sta line,x
        dex
        bpl dr0t
dr0p    lda #C_GRY2
        ldx #$80
        jmp putline

; Row 1: disk header in reverse light blue.
drawhdr lda #1
        jsr rowptr
        lda #" "
        sta line
        sta line+1
        ldx #0
-       cpx hdrlen
        beq +
        cpx #LISTW-2
        beq +
        lda hdr,x
        sta line+2,x
        inx
        bne -
+       inx
        inx
        jsr padline
        lda #C_LBLU
        ldx #$80
        jmp putline

; All 22 list rows of the current page.
drawlist
        lda #0
        sta drow
dlnext  lda top
        clc
        adc drow
        bcs dlblank
        ldx last
        cpx #$ff
        beq dlblank
        cmp last
        beq dlent
        bcc dlent
dlblank lda drow
        clc
        adc #ROW0
        jsr rowptr
        ldx #0
        jsr padline
        lda #C_LBLU
        ldx #0
        jsr putline
        jmp dlinc
dlent   jsr drawent
dlinc   inc drow
        lda drow
        cmp #NROWS
        bne dlnext
        rts

; Draw entry A on its row, highlighted when it is the cursor entry.
drawent sta didx
        sec
        sbc top
        clc
        adc #ROW0
        jsr rowptr
        lda didx
        jsr getent
        lda ent
        ldx ent+1
        jsr num2dec
        ldx #0
-       lda decbuf,x
        sta line,x
        inx
        cpx declen
        bne -
        ldy #0
-       cpy ent+2
        beq +
        cpx #LISTW
        beq +
        lda ent+3,y
        sta line,x
        inx
        iny
        bne -
+       jsr padline
        lda didx
        cmp pos
        bne +
        lda #C_CYAN
        ldx #$80
        jmp putline
+       lda #C_LBLU
        ldx #0
        jmp putline

; Screen and colour pointers for row A (row * 40).
rowptr  sta scr
        asl
        asl
        adc scr
        ldx #0
        stx scr+1
        asl
        rol scr+1
        asl
        rol scr+1
        asl
        rol scr+1
        sta scr
        sta col
        lda scr+1
        ora #>COLRAM
        sta col+1
        eor #(>COLRAM) ^ (>SCR)
        sta scr+1
        rts

; Fill line from X to LISTW with spaces.
padline lda #" "
-       cpx #LISTW
        bcs +
        sta line,x
        inx
        bne -
+       rts

; Write line (PETSCII, LISTW wide) to the row at scr in colour A,
; X = $80 for reverse.
putline stx rvs
        sta tcol
        ldy #LISTW-1
-       lda line,y
        jsr p2s
        ora rvs
        sta (scr),y
        lda tcol
        sta (col),y
        dey
        bpl -
        rts

; Text at (scr)+xcol from (zp2) up to the 0; the first rvs characters
; are reversed.
putrich ldy #0
        lda (zp2),y
        inc zp2
        bne +
        inc zp2+1
+       tax
        beq prend
        jsr p2s
        ldx rvs
        beq +
        ora #$80
        dec rvs
+       ldy xcol
        sta (scr),y
        lda tcol
        sta (col),y
        inc xcol
        bne putrich
prend   rts

; PETSCII to screen code.
p2s     cmp #$20
        bcc p2sc
        cmp #$40
        bcc p2sx
        cmp #$60
        bcc p2s40
        cmp #$80
        bcc p2s20
        cmp #$a0
        bcc p2sc
        cmp #$c0
        bcc p2s40
        cmp #$ff
        beq +
        and #$7f
        rts
+       lda #$5e
        rts
p2s20   sec
        sbc #$20
        rts
p2s40   sec
        sbc #$40
p2sx    rts
p2sc    and #$1f
        ora #$40
        rts

; ------------------------------------------------- messages on a list row
currow  lda pos
        sec
        sbc top
        clc
        adc #ROW0
        sta row
        rts

; Message on the cursor row; the text follows the JSR.
msgi    pla
        sta zp2
        pla
        sta zp2+1
        inc zp2
        bne +
        inc zp2+1
+       jsr currow
        lda zp2
        ldx zp2+1
        jsr msgrow
        lda zp2
        sec
        sbc #1
        tax
        lda zp2+1
        sbc #0
        pha
        txa
        pha
        rts

; Clear the list part of row and print text A/X there in white.
msgrow  sta zp2
        stx zp2+1
        lda row
        jsr rowptr
        ldx #0
        jsr padline
        lda #C_WHT
        ldx #0
        jsr putline
        lda #0
        sta xcol
        sta rvs
        lda #C_WHT
        sta tcol
        jmp putrich


; Append PETSCII text A/X after the last message (or CHROUT on hand-off).
strout  sta zp2
        stx zp2+1
        ldy #0
-       lda (zp2),y
        beq +
        jsr chrout2
        iny
        bne -
+       rts

chrout2 bit hoff
        bmi +
        sty zp3
        jsr p2s
        ldy xcol
        sta (scr),y
        lda #C_WHT
        sta (col),y
        inc xcol
        ldy zp3
        rts
+       jmp CHROUT

hexsa   lda saddr
        ldx saddr+1
hex16   pha
        txa
        jsr hexout
        pla
hexout  pha
        lsr
        lsr
        lsr
        lsr
        jsr +
        pla
        and #$0f
+       tax
        lda hexdig,x
        jmp chrout2

hexdig  .text "0123456789ABCDEF"

; Start address as "2049 ($0801)" after the last message.
decsa   lda saddr
        ldx saddr+1
        jsr decout
        jsr stri
        .null " ($"
        jsr hexsa
        lda #")"
        jmp chrout2

; Decimal A (lo) / X (hi) at the cursor.
decout  jsr num2dec
        ldy #0
-       lda decbuf,y
        jsr chrout2
        iny
        cpy declen
        bne -
        rts

; A/X -> decbuf without leading zeros, declen.
num2dec sta zp3
        stx zp3+1
        lda #0
        sta declen
        ldx #4
nd1     lda #"0"
        sta ndig
nd2     lda zp3
        sec
        sbc pow10lo,x
        tay
        lda zp3+1
        sbc pow10hi,x
        bcc nd3
        sta zp3+1
        sty zp3
        inc ndig
        bne nd2
nd3     lda ndig
        cpx #0
        beq nd4
        cmp #"0"
        bne nd4
        ldy declen
        beq nd5
nd4     ldy declen
        sta decbuf,y
        inc declen
nd5     dex
        bpl nd1
        rts

pow10lo .byte <1, <10, <100, <1000, <10000
pow10hi .byte >1, >10, >100, >1000, >10000

; Digits of A as the default of a 2 character numeric field.
numfield
        ldx #0
        jsr num2dec
        ldx declen
        stx inlen
        dex
-       lda decbuf,x
        sta inbuf,x
        dex
        bpl -
        lda #1
        sta infresh
        sta inmode
        lda #2
        sta inmax
        rts

; Empty 16 character name field at column A.
namefield
        sta incol
        lda #0
        sta inlen
        sta inmode
        sta infresh
        lda #16
        sta inmax
        jmp lineinput

; Number typed in inbuf -> A (0 when empty).
parsenum
        lda #0
        ldx #0
-       cpx inlen
        beq +
        sta zp3
        asl
        asl
        adc zp3
        asl
        sta zp3
        lda inbuf,x
        and #$0f
        clc
        adc zp3
        inx
        bne -
+       rts

; Line editor on row (row) from column incol, up to inmax characters.
; inmode 1 = digits only. With infresh set the first key replaces the
; default. RETURN: carry clear. RUN/STOP: carry set.
lineinput
        lda row
        jsr rowptr
liloop  jsr infield
        jsr getkey
        cmp #$0d
        beq inret
        cmp #$03
        beq inesc
        cmp #$14
        bne +
        lda #0
        sta infresh
        lda inlen
        beq liloop
        dec inlen
        jmp liloop
+       ldx inmode
        beq +
        cmp #"0"
        bcc liloop
        cmp #"9"+1
        bcs liloop
        bcc inadd
+       cmp #$22
        beq liloop
        cmp #$20
        bcc liloop
        cmp #$80
        bcc inadd
        cmp #$a0
        bcc liloop
inadd   ldx infresh
        beq +
        ldx #0
        stx inlen
        stx infresh
+       ldx inlen
        cpx inmax
        bcs liloop
        sta inbuf,x
        inc inlen
        jmp liloop
inret   lda #" "
        jsr infld0
        clc
        rts
inesc   sec
        rts

infield lda #$a0
infld0  sta zp3
        ldy incol
        ldx #0
-       cpx inlen
        beq +
        lda inbuf,x
        jsr p2s
        sta (scr),y
        lda #C_WHT
        sta (col),y
        iny
        inx
        bne -
+       cpy #LISTW
        bcs +
        lda zp3
        sta (scr),y
        lda #C_WHT
        sta (col),y
        iny
+       lda #" "
-       cpy #LISTW
        bcs +
        sta (scr),y
        iny
        bne -
+       rts

getkey  jsr GETIN
        beq getkey
        rts

; ================================================================ text
s_title .text "   SubDir Commander 2026   "
s_seldrv
        .null " Select drive:"
s_press .text " PRESS ANY KEY ...         "
s_rs    .text "runsys"
s_deleted
        .text "                  deleted"
s_bfree .null " blocks free."
s_cr    .null ",r"
s_cw    .null ",w"
e_devnp .null "Device is not present !"
e_rd    .null "Read error !"
e_abort .null "Copy aborted !"

; Key panel: row, then rich text.
panel
        .byte 1, 12
        .null "NumericKeys:"
        .byte 2, 1
        .null "1", " ListDirect"
        .byte 3, 1
        .null "2", " ValidateDi"
        .byte 4, 1
        .null "3", " RenameFile"
        .byte 5, 1
        .null "4", " CopyFile"
        .byte 6, 1
        .null "5", " StartAdres"
        .byte 7, 1
        .null "6", " DeleteFile"
        .byte 8, 1
        .null "7", " RunOpenDir"
        .byte 9, 1
        .null "8", " LoadOpenDi"
        .byte 11, 12
        .null "SD2IEC Keys:"
        .byte 12, 1
        .null "^", " Go1LevelUp"
        .byte 14, 12
        .null "CRSR Keys:  "
        .byte 15, 3
        .null "U/D", " LineUpDn"
        .byte 16, 3
        .null "L/R", " PageUpDn"
        .byte 18, 6
        .null "Return", $a0, "RunOp"
        .byte 19, 1
        .null "_", " to ExitApp"
        .byte $ff

; ============================================================ variables
; Hot variables in the BASIC area of zero page ($4B-$72). The KERNAL does
; not use it; BASIC's bytes (including its function JMP at $54) are saved at
; start and put back on exit and while a loaded program runs.
ZPVARS  = $4b
        .virtual ZPVARS
dev     .byte ?
tdev    .byte ?
pos     .byte ?
oldpos  .byte ?
top     .byte ?
last    .byte ?
row     .byte ?
xcol    .byte ?
tcol    .byte ?
rvs     .byte ?
hoff    .byte ?
eof     .byte ?
errnum  .byte ?
namelen .byte ?
newlen  .byte ?
inlen   .byte ?
inmax   .byte ?
incol   .byte ?
inmode  .byte ?
infresh .byte ?
declen  .byte ?
cmdlen  .byte ?
ndig    .byte ?
didx    .byte ?
drow    .byte ?
kcount  .byte ?
qpos    .byte ?
ro      .byte ?
locked  .byte ?
isamp   .byte ?
spmode  .byte ?
runflag .byte ?
ldml    .byte ?
first   .byte ?
tries   .byte ?
xbad    .byte ?
bfree   .word ?
blocks  .word ?
zpend
        .endv
        .cerror zpend > $73, "zero page variables overrun CHRGET"

        .virtual
savesp  .byte ?
saddr   .word ?
eaddr   .word ?
zsave   .fill zpend - ZPVARS
bsave   .fill zpend - ZPVARS
type    .fill 3
namebuf .fill 16
newname .fill 16
inbuf   .fill 17
decbuf  .fill 6
kbuf    .fill 10
cmdbuf  .fill 48
statbuf .fill 42
oslen   .byte ?
osbuf   .fill LISTW
hdrlen  .byte ?
hdr     .fill 32
line    .fill LISTW + 1
ent     .fill ENTSZ
        .align 256
bufstart
        .endv
