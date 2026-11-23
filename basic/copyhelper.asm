; Cross-drive file copy helper for SubDirCommand.38 (BASIC).
; BASIC opens the source as logical file 2 and the target as logical file 3,
; then calls SYS 828. Data moves in 8 KB chunks through the RAM under the
; BASIC ROM ($A000-$BFFF). Writes there go to RAM; reads need $01=$36.
; Result in $02: $40 = whole file copied, $FF = read/write error or STOP.

CHKIN   = $ffc6
CHKOUT  = $ffc9
CHRIN   = $ffcf
CHROUT  = $ffd2
CLRCHN  = $ffcc
STOP    = $ffe1
status  = $90
result  = $02
endp    = $fb           ; end of data in buffer (lo = offset, hi = page)
src     = $fd
BUFHI   = $a0
BUFEND  = $c0

        * = $033c

copy    lda #0
        sta result
fill    jsr CLRCHN
        ldy #0
        sty status
        ldx #2
        jsr CHKIN
        bcs fail
        ldy #0
        sty endp
        lda #BUFHI
        sta endp+1
rd      jsr CHRIN
        sta (endp),y
        lda status
        bne stat
        iny
        bne rd
        jsr STOP
        beq fail
        inc endp+1
        lda endp+1
        cmp #BUFEND
        bne rd
        beq flush
stat    and #$bf
        bne fail
        lda #$40
        sta result
        iny
        bne flush
        inc endp+1
flush   sty endp
        jsr CLRCHN
        lda #0
        sta status
        ldx #3
        jsr CHKOUT
        bcs fail
        ldy #0
        sty src
        lda #BUFHI
        sta src+1
wl      lda src+1
        cmp endp+1
        bne wb
        cpy endp
        beq wdone
wb      lda #$36
        sta $01
        lda (src),y
        ldx #$37
        stx $01
        jsr CHROUT
        iny
        bne wl
        inc src+1
        bne wl
wdone   lda status
        bne fail
        lda result
        beq fill
        jmp CLRCHN
fail    lda #$ff
        sta result
        jmp CLRCHN
