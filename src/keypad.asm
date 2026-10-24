; ============================================================================================================
; Hex keypad for the seed (bank $11).  Big gold glyphs (16x16) for the typed code and for 18 keys in a 6x3 grid:
;   0 1 2 3 4 5 / 6 7 8 9 b A.. see tools/bigfont.py: 0-5, 6-b, C D E F <- END.  The cursor can only stop on real keys.
; The hex digits are drawn glyphs (tools/bigfont.py -> kp_gfx), uploaded to VRAM tiles 256..319 when the keypad opens.
; Called from the menu code (bank $0F, DBR = $0F, M=X=16 bit) with JSL.  Scratch: low RAM $1FB2.. (the unused lap-record table).
; ============================================================================================================
.a16
.i16
KS_Y0   = $1FB2
KS_Y1   = $1FB4
KS_X0   = $1FB6
KS_X1   = $1FB8
KS_SLOT = $1FBA
KS_J    = $1FBC
KS_Y    = $1FBE
KS_TX   = $1FC0
KS_MASK = $1FC2
KS_PTR  = $1FC4
KS_DST  = $1FC6
KS_P01  = $1FC8
KS_P23  = $1FCA
KS_T    = $1FCC
KS_T2   = $1FCE
KS_SRC  = $1FD0
KP_CUR  = $1FD2
KP_PAD  = $1FD4


.org $118000

; ---- upload the hex digit glyphs (kp_gfx, 3 KB drawn by tools/bigfont.py) to VRAM tile 256.. (screen forced blank, NMI off meanwhile) ----
kp_build_glyphs:
    rep #$30
    sep #$20
    lda #0
    sta.l $004200
    lda #$80
    sta.l $002100               ; forced blank
    sta.l $002115               ; VMAIN: increment after the high byte
    rep #$20
    lda #$2000
    sta.l $002116
    ldx #0
kb_up:
    lda.l kp_gfx,x
    sta.l $002118
    inx
    inx
    cpx #$0C00
    bcc kb_up
    sep #$20
    lda #$81
    sta.l $004200               ; NMI + joypad again
    rep #$30
    rtl

; ---- screen --------------------------------------------------------------------------------------------------------
kp_quad:                        ; A = tile of the top-left 8x8, X = byte offset in the tilemap buffer ($0C6C+X): 2x2 tiles, sprite layout
    sta $0C6C,x
    inc a
    sta $0C6E,x
    clc
    adc #15
    sta $0CAC,x
    inc a
    sta $0CAE,x
    rts

kp_draw_keys:                   ; the 16 digits, the delete arrow and END
    ldy #0                      ; cell
kd_l:
    tya
    asl a
    sta KS_T
    asl a
    clc
    adc KS_T                    ; 6 bytes per cell entry
    tax
    lda.l kp_cells,x            ; buffer offset
    sta KS_T2
    cpy #17
    bcs kd_end
    tya
    asl a
    tax
    lda.l kp_keys,x
    ldx KS_T2
    jsr kp_quad
    iny
    bra kd_l
kd_end:                         ; END = E N D, three glyphs
    ldx #0
    ldy KS_T2
kd_e:
    lda.l kp_end_tiles,x
    phx
    tyx
    jsr kp_quad
    plx
    iny
    iny
    iny
    iny
    inx
    inx
    cpx #6
    bcc kd_e
    rts

kp_draw_code:                   ; typed characters ($68.., $5E = count) as big glyphs in the box (tile row 7, from column 8)
    ldy #0
kc_l:
    tya
    asl a
    asl a
    clc
    adc #464                    ; (7*32+8)*2 + 4*slot
    tax
    cpy $5E
    bcs kc_blank
    lda $0068,y
    and #$00FF
    cmp #$0041
    bcc kc_d
    sbc #$0007
kc_d:
    and #$000F
    phx
    asl a
    tax
    lda.l kp_keys,x
    plx
    jsr kp_quad
    bra kc_n
kc_blank:
    lda #0
    sta $0C6C,x
    sta $0C6E,x
    sta $0CAC,x
    sta $0CAE,x
kc_n:
    iny
    cpy #8
    bcc kc_l
    rts

kp_cursor:                      ; selection bar under the current key + the text cursor sprite
    lda KP_CUR
    sta KS_T
    asl a
    clc
    adc KS_T
    asl a                       ; 6 bytes per cell
    tax
    lda.l kp_cells+2,x
    sta $48
    lda.l kp_cells+4,x
    sta $4A
    ldx #$0008
    jsl t_bar
    jsl t_cur
    jsl t_oam
    lda #$0084
    sta $0424
    rts

kp_show:                        ; (re)draw everything that depends on the typed count / cursor
    jsr kp_draw_code
    jsr kp_cursor
    rts

; ---- entry point: JSL kp_run, returns with the typed characters in $68.. and the count in $5E -------------------
kp_run:
    rep #$30
    lda #$2020
    sta $68
    sta $6A
    sta $6C
    sta $6E
    stz $5E
    stz KP_CUR
    jsl kp_build_glyphs
    jsr kp_draw_keys
    jsr kp_draw_code
    jsr kp_cursor
    jsl t_fadein
kr_loop:
    lda #$0001
    jsl t_vbl
    lda $81
    asl a
    tay
    lda $000A,y
    sta KP_PAD
    and #$FFF0
    beq kr_loop
    lda KP_PAD
    and #$1000                  ; START = finish
    bne kr_done
    lda KP_PAD
    and #$4040                  ; Y, X = delete (as in the name entry)
    beq kr_nodel
    jsr kp_delete
    bra kr_rel
kr_nodel:
    lda KP_PAD
    and #$8080                  ; A, B = press the key (as in the name entry)
    beq kr_nopress
    lda KP_CUR
    cmp #17
    beq kr_done
    cmp #16
    bne kr_digit
    jsr kp_delete
    bra kr_rel
kr_digit:
    jsr kp_append
    bra kr_rel
kr_nopress:
    jsr kp_move
kr_rel:
    jsr kp_show
kr_wait:
    lda #$0001
    jsl t_vbl
    lda $81
    asl a
    tay
    lda $000A,y
    bne kr_wait
    bra kr_loop
kr_done:
    rtl

kp_delete:
    lda $5E
    beq kd_none
    dec $5E
kd_none:
    rts

kp_append:                      ; A = key 0..15
    ldx $5E
    cpx #8
    bcs ka_full
    cmp #10
    bcc kap_d
    adc #6                      ; 'A'-'0'-10 = 7 (carry is set)
kap_d:
    clc
    adc #$0030
    pha
    txy
    pla
    sep #$20
    sta $0068,y
    rep #$20
    inc $5E
ka_full:
    rts

kp_move:                        ; directions: wrap inside the row / across the rows; cells 0..17, row = c/6
    lda KP_CUR
    ldx #0                      ; row = c / 6, col = c % 6
km_div:
    cmp #6
    bcc km_got
    sbc #6
    inx
    bra km_div
km_got:
    sta KS_T                    ; col
    stx KS_T2                   ; row
    lda KP_PAD
    and #$0200                  ; left
    beq km_r
    lda KS_T
    bne km_l1
    lda #6
km_l1:
    dec a
    sta KS_T
    bra km_set
km_r:
    lda KP_PAD
    and #$0100                  ; right
    beq km_u
    lda KS_T
    inc a
    cmp #6
    bcc km_r1
    lda #0
km_r1:
    sta KS_T
    bra km_set
km_u:
    lda KP_PAD
    and #$0800                  ; up
    beq km_d
    lda KS_T2
    bne km_u1
    lda #3
km_u1:
    dec a
    sta KS_T2
    bra km_set
km_d:
    lda KP_PAD
    and #$0400                  ; down
    beq km_out
    lda KS_T2
    inc a
    cmp #3
    bcc km_d1
    lda #0
km_d1:
    sta KS_T2
km_set:                         ; c = row*6 + col
    lda KS_T2
    asl a
    sta KS_SRC
    asl a
    clc
    adc KS_SRC
    clc
    adc KS_T
    sta KP_CUR
km_out:
    rts
