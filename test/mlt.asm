        * = ADDR
        ldx #0
-       lda msg,x
        beq +
        sta $0400+40*24,x
        inx
        bne -
+       rts
msg     .text "ML OK"
        .byte 0
