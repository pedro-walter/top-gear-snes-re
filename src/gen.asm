; ============================================================================================================
; Top Gear (USA) randomizer - on-console track generator (65816).  Literal port of tools/trackgen.py.
; Lives in ROM bank $10.  Scratch RAM is WRAM bank $7F (never used by the game); DBR=$7F while it runs.
; M=16 bit, X=16 bit everywhere (rep #$30).  Direct page = $0000 (game's); $1A-$1C are used as a 24-bit pointer.
; ============================================================================================================
.a16
.i16

; ---- scratch variables (bank $7F; all >= $0100 so the assembler uses absolute addressing) -----------------
SEED    = $F800         ; 4 bytes   persistent seed (menu writes it)
RS      = $F810         ; rng state low word
RSH     = $F812         ; rng state high word
T0      = $F820
T1      = $F822
T2      = $F824
T3      = $F826
T4      = $F828
T5      = $F82A
CNT     = $F82C
CNT2    = $F82E
ENV     = $F830
LEN     = $F832         ; L pieces per lap
PN      = $F834         ; P = L+1 pieces
LAPS    = $F836
HILL    = $F838
CURVY   = $F83A
PP      = $F83C         ; pit piece
PITW    = $F83E         ; 00:DF24 style pit word
POS     = $F840
END     = $F842
REM     = $F844
EVN     = $F846         ; bytes used in event buffer (2 per entry)
SG      = $F848
KK      = $F84A
NN      = $F84C
NLEV    = $F84E
NBUMP   = $F850
SN      = $F852         ; source track piece count
SSC     = $F854         ; source scenery stream pointer (bank 0C)
SOB     = $F856         ; source object stream pointer
PITSRC  = $F858
ALCNT   = $F85A
JJ      = $F85C
RUN     = $F85E
PIDX    = $F860
DOFF    = $F862
TBL     = $F864
ARR     = $F866
NEGF    = $F868
DIFF    = $F86A
MASKD   = $F86C
DD      = $F870         ; 4 words D[0..3]
T6      = $F878
LIM     = $F87A
SLOPE   = $F000         ; 48 words
CURVE   = $F080         ; 48 words
SCEN    = $F100         ; 48 words
OKF     = $F180         ; 64 words
ALLOW   = $F200         ; 64 words
EVB     = $F280         ; 16 words
RECS    = $F400         ; 96 records * 10 bytes (5 words each) = 960 bytes -> $17C0

.org $108000

; ---------------------------------------------------------------------------------------------------------
; rng
rng_step:                       ; 32-bit Galois LFSR step, mask $80200003
    lsr RSH
    ror RS
    bcc rs_end
    lda RSH
    eor #$8020
    sta RSH
    lda RS
    eor #$0003
    sta RS
rs_end:
    rts

rng_byte:                       ; A = next byte (clobbers Y)
    ldy #8
rb_l:
    jsr rng_step
    dey
    bne rb_l
    lda RS
    and #$00FF
    rts

rnd:                            ; A = n (1..255) -> A = (byte*n)>>8  (clobbers Y; preserves X)
    phx
    sta T0
    jsr rng_byte
    sta T1
    lda T0
    xba
    sta T2
    ldx #8
    lda #0
rn_l:
    lsr T1
    bcc rn_s
    clc
    adc T2
rn_s:
    ror a
    dex
    bne rn_l
    xba
    and #$00FF
    plx
    rts

; ---------------------------------------------------------------------------------------------------------
; event buffer helpers
ev_add:                         ; append A
    ldy EVN
    sta EVB,y
    iny
    iny
    sty EVN
    rts

ev_neg:                         ; id -> (256-id)&255 for every nonzero entry
    ldx #0
en_l:
    cpx EVN
    bcs en_e
    lda EVB,x
    beq en_n
    eor #$00FF
    inc a
    and #$00FF
    sta EVB,x
en_n:
    inx
    inx
    bra en_l
en_e:
    rts

ev_commit:                      ; X = array base; writes the event entries at POS while POS < END
    stx T5
    ldx #0
ec_l:
    cpx EVN
    bcs ec_e
    lda POS
    cmp END
    bcs ec_e
    asl a
    clc
    adc T5
    tay
    lda EVB,x
    sta $0000,y
    inc POS
    inx
    inx
    bra ec_l
ec_e:
    rts

clear_arr:                      ; X = base, clears 48 words
    ldy #48
ca_l:
    stz $0000,x
    inx
    inx
    dey
    bne ca_l
    rts

; ---------------------------------------------------------------------------------------------------------
; slope walk
slope_walk:
    ldx #SLOPE
    jsr clear_arr
    lda #1
    sta POS
    lda PN
    dec a
    sta END
    lda HILL
    asl a
    clc
    adc #3
    sta NLEV
    lda HILL
    clc
    adc #2
    cmp #5
    bcc sw_nb
    lda #4
sw_nb:
    sta NBUMP
sw_loop:
    lda POS
    cmp END
    bcc sw_go
    rts
sw_go:
    lda END
    sec
    sbc POS
    sta REM
    stz EVN
    lda #100
    jsr rnd
    sta KK
    cmp #60
    bcc sw_nohill
    ; ---- long hill
    lda NLEV
    jsr rnd
    sta T3
    asl a
    clc
    adc T3
    sta T3                      ; level index * 3
    lda #4
    jsr rnd
    sta NN
    lda #2
    jsr rnd
    sta SG
    lda NN
    clc
    adc #2
    cmp REM
    beq sw_fit
    bcs sw_flat
sw_fit:
    ldx T3
    lda.l slope_levels,x
    and #$00FF
    jsr ev_add
    lda NN
    sta CNT
sw_pl:
    lda CNT
    beq sw_pd
    ldx T3
    lda.l slope_levels+1,x
    and #$00FF
    jsr ev_add
    dec CNT
    bra sw_pl
sw_pd:
    ldx T3
    lda.l slope_levels+2,x
    and #$00FF
    jsr ev_add
    bra sw_sign
sw_nohill:
    cmp #35
    bcc sw_flat
    ; ---- bump
    lda NBUMP
    jsr rnd
    tax
    lda.l slope_bumps,x
    and #$00FF
    sta T3
    lda #2
    jsr rnd
    sta SG
    lda T3
    jsr ev_add
sw_sign:
    lda SG
    beq sw_commit
    jsr ev_neg
sw_commit:
    ldx #SLOPE
    jsr ev_commit
    jmp sw_loop
sw_flat:
    lda #5
    jsr rnd
    inc a
    cmp REM
    bcc sw_fl2
    lda REM
sw_fl2:
    clc
    adc POS
    sta POS
    jmp sw_loop

; ---------------------------------------------------------------------------------------------------------
; curve walk
curve_walk:
    ldx #CURVE
    jsr clear_arr
    lda #1
    sta POS
    lda PN
    dec a
    sta END
    lda CURVY
    clc
    adc #2
    sta NLEV                    ; number of curve levels (2..4)
cw_loop:
    lda POS
    cmp END
    bcc cw_go
    rts
cw_go:
    lda END
    sec
    sbc POS
    sta REM
    stz EVN
    lda #100
    jsr rnd
    sta KK
    cmp #72
    bcc cw_nosw
    ; ---- sweeper
    lda NLEV
    cmp #3
    bcc cw_l1
    lda #3
cw_l1:
    jsr rnd
    sta T3
    asl a
    clc
    adc T3
    sta T3
    lda #3
    jsr rnd
    sta NN
    lda #2
    jsr rnd
    sta SG
    lda #3
    jsr rnd
    sta T4                      ; s
    ; length of one = NN+2 ; fits?
    lda NN
    clc
    adc #2
    sta T5                      ; len
    lda T4
    bne cw_one
    lda T5
    asl a
    cmp REM
    beq cw_two
    bcc cw_two
cw_one:
    lda T5
    cmp REM
    beq cw_b1
    bcs cw_flat
cw_b1:
    jsr cw_build
    bra cw_sign
cw_two:
    jsr cw_build
    ; append the mirrored copy (each entry negated)
    ldx #0
    lda EVN
    sta T2
cw_m:
    cpx T2
    bcs cw_sign
    lda EVB,x
    eor #$00FF
    inc a
    and #$00FF
    phx
    jsr ev_add
    plx
    inx
    inx
    bra cw_m
cw_nosw:
    cmp #38
    bcc cw_flat
    ; ---- single-piece bump
    lda NLEV
    jsr rnd
    sta T3
    asl a
    asl a
    clc
    adc T3                      ; lv*5
    sta T3
    lda #5
    jsr rnd
    clc
    adc T3
    tax
    lda.l curve_bumps,x
    and #$00FF
    sta T3
    lda #2
    jsr rnd
    sta SG
    lda T3
    jsr ev_add
cw_sign:
    lda SG
    beq cw_commit
    jsr ev_neg
cw_commit:
    ldx #CURVE
    jsr ev_commit
    jmp cw_loop
cw_flat:
    lda #6
    jsr rnd
    inc a
    cmp REM
    bcc cw_fl2
    lda REM
cw_fl2:
    clc
    adc POS
    sta POS
    jmp cw_loop

cw_build:                       ; event = up, plateau * NN, down   (levels table index T3)
    ldx T3
    lda.l curve_levels,x
    and #$00FF
    jsr ev_add
    lda NN
    sta CNT
cb_l:
    lda CNT
    beq cb_d
    ldx T3
    lda.l curve_levels+1,x
    and #$00FF
    jsr ev_add
    dec CNT
    bra cb_l
cb_d:
    ldx T3
    lda.l curve_levels+2,x
    and #$00FF
    jsr ev_add
    rts

; ---------------------------------------------------------------------------------------------------------
; pick scenery + objects from runs of the environment's own original track
pick_source:
    lda ENV
    asl a
    sta T0
    asl a
    asl a
    clc
    adc T0
    tax                         ; 10*env
    lda.l $0C8402,x
    and #$003F
    inc a
    sta SN                      ; pieces of the source track
    lda.l $0C8408,x
    sta SSC
    lda.l $0C840A,x
    sta SOB
    ; pit piece of the source track (to exclude it)
    lda ENV
    asl a
    tax
    lda.l $00DF24,x
    ldx #$FFFF
    stx PITSRC
    cmp #$FFFF
    beq ps_nop
    and #$7FFF
    asl a
    clc
    adc #512
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a
    sta PITSRC
ps_nop:
    ; flags + allowed list
    ldx #0
    ldy #64
ps_cl:
    stz OKF,x
    inx
    inx
    dey
    bne ps_cl
    stz ALCNT
    lda SN
    dec a
    sta T6
    ldy #1
ps_k:
    cpy T6
    bcs ps_kd
    tya
    cmp PITSRC
    beq ps_bad
    tya
    clc
    adc SSC
    tax
    lda.l $0C0000,x
    and #$00FF
    cmp #20
    beq ps_bad
    tya
    asl a
    sta T0
    asl a
    asl a
    clc
    adc T0                      ; 10*k
    clc
    adc SOB
    clc
    adc #4
    tax
    lda.l $0C0000,x
    and #$00FF
    sec
    sbc #41
    cmp #8
    bcc ps_bad
    txa
    clc
    adc #5
    tax
    lda.l $0C0000,x
    and #$00FF
    sec
    sbc #41
    cmp #8
    bcc ps_bad
    tya
    asl a
    tax
    lda #1
    sta OKF,x
    lda ALCNT
    asl a
    tax
    tya
    sta ALLOW,x
    inc ALCNT
ps_bad:
    iny
    bra ps_k
ps_kd:
    ; start/finish piece 0 and the wrap-around copy P-1 come from source piece 0
    ldx SSC
    lda.l $0C0000,x
    and #$00FF
    sta SCEN
    ldy PN
    dey
    tya
    asl a
    tax
    lda SCEN
    sta SCEN,x
    ldx SOB
    ldy #RECS
    jsr copy10
    lda SOB
    clc
    adc #5
    tax
    ldy #RECS+10
    jsr copy10
    ; piece P-1: dest = RECS + 20*(P-1)
    lda PN
    dec a
    jsr rec_dest
    sta T4
    ldx SOB
    ldy T4
    jsr copy10
    lda SOB
    clc
    adc #5
    tax
    lda T4
    clc
    adc #10
    tay
    jsr copy10
    ; runs
    lda #1
    sta POS
    lda PN
    dec a
    sta END
ps_o:
    lda POS
    cmp END
    bcc ps_o2
    rts
ps_o2:
    lda ALCNT
    jsr rnd
    asl a
    tax
    lda ALLOW,x
    sta JJ
    lda #5
    jsr rnd
    clc
    adc #2
    sta RUN
ps_i:
    lda RUN
    beq ps_o
    lda POS
    cmp END
    bcs ps_o
    lda JJ
    asl a
    tax
    lda OKF,x
    beq ps_o
    ; scenery byte
    lda JJ
    clc
    adc SSC
    tax
    lda.l $0C0000,x
    and #$00FF
    pha
    lda POS
    asl a
    tax
    pla
    sta SCEN,x
    ; records: src = SOB + 10*J, dst = RECS + 20*POS
    lda JJ
    asl a
    sta T0
    asl a
    asl a
    clc
    adc T0
    clc
    adc SOB
    pha
    lda POS
    jsr rec_dest
    tay
    plx
    jsr copy10
    lda JJ
    asl a
    sta T0
    asl a
    asl a
    clc
    adc T0
    clc
    adc SOB
    clc
    adc #5
    tax                         ; source offset of the second half record (bytes)
    lda POS
    jsr rec_dest
    clc
    adc #10
    tay
    jsr copy10
    inc POS
    inc JJ
    dec RUN
    bra ps_i

rec_dest:                       ; A = piece -> A = RECS + 20*piece
    sta T0
    asl a
    asl a
    clc
    adc T0                      ; 5*p
    asl a
    asl a                       ; 20*p
    clc
    adc #RECS
    rts

copy10:                         ; X = source offset (bank 0C) of a 5-byte record, Y = destination (RECS..) ; copies 5 bytes -> 5 words
    lda #5
    sta CNT2
c10:
    lda.l $0C0000,x
    and #$00FF
    sta $0000,y
    inx
    iny
    iny
    dec CNT2
    bne c10
    rts

; ---------------------------------------------------------------------------------------------------------
; pit
pit_setup:
    lda LEN
    sec
    sbc #8
    jsr rnd
    clc
    adc #4
    sta PP
    lda #3
    jsr rnd
    sta T0
    asl a
    clc
    adc T0
    tax                         ; style*3
    lda PP
    asl a
    tay
    lda.l pit_styles,x
    and #$00FF
    sta SCEN,y
    lda.l pit_styles+2,x
    and #$00FF
    sta T2                      ; group
    lda.l pit_styles+1,x
    and #$00FF
    sta T1                      ; side
    lda PP
    jsr rec_dest
    tay
    lda #21
    sta $0000,y
    lda #58
    sta $0002,y
    lda #0
    sta $0004,y
    sta $0006,y
    lda T2
    sta $0008,y
    lda #21
    sta $000A,y
    lda #58
    sta $000C,y
    lda #0
    sta $000E,y
    sta $0010,y
    lda T2
    inc a
    sta $0012,y
    ; pit word = side<<15 | (PP*512 - 256)
    lda PP
    xba
    asl a                       ; PP*512
    sec
    sbc #256
    sta T3
    lda T1
    beq pw_s
    lda T3
    ora #$8000
    sta T3
pw_s:
    lda T3
    sta PITW
    rts

; ---------------------------------------------------------------------------------------------------------
; expansion into the WRAM tables (same as 00:BF44)
expand_stream:                  ; TBL = template pointer table (bank 0C), ARR = stream array, [$1A] = destination
    stz PIDX
    stz DOFF
es_p:
    lda PIDX
    cmp PN
    bcc es_go
    rts
es_go:
    asl a
    clc
    adc ARR
    tax
    lda $0000,x
    and #$00FF
    stz NEGF
    cmp #$0080
    bcc es_pos
    eor #$00FF
    inc a
    and #$00FF
    ldx #1
    stx NEGF
es_pos:
    asl a
    clc
    adc TBL
    tax
    lda.l $0C0000,x
    tax                         ; X = template pointer
    ldy DOFF
    lda #32
    sta CNT
    lda NEGF
    bne es_neg
es_wp:
    lda.l $0C0000,x
    sta [$1A],y
    inx
    inx
    iny
    iny
    dec CNT
    bne es_wp
    bra es_nx
es_neg:
    lda.l $0C0000,x
    eor #$FFFF
    inc a
    sta [$1A],y
    inx
    inx
    iny
    iny
    dec CNT
    bne es_neg
es_nx:
    sty DOFF
    inc PIDX
    bra es_p

expand_scen:
    lda #$5800
    sta $1A
    lda #$007E
    sta $1C
    stz PIDX
    stz DOFF
xs_p:
    lda PIDX
    cmp PN
    bcc xs_go
    rts
xs_go:
    asl a
    tax
    lda SCEN,x
    asl a
    tax
    lda.l $0C8545,x
    tax
    ldy DOFF
    lda #32
    sta CNT
xs_w:
    lda.l $0C0000,x
    sta [$1A],y
    inx
    inx
    iny
    iny
    dec CNT
    bne xs_w
    sty DOFF
    inc PIDX
    bra xs_p

expand_objs:
    lda #$6400
    sta $1A
    lda #$007E
    sta $1C
    lda.l $001F10
    and #$00FF
    tax
    lda.l $0C8541,x
    and #$E000
    sta MASKD
    stz PIDX
    stz DOFF
    lda PN
    asl a
    sta LIM
xo_r:
    lda PIDX
    cmp LIM
    bcc xo_go
    rts
xo_go:
    ; record base = RECS + 10*r
    lda PIDX
    sta T0
    asl a
    asl a
    clc
    adc T0
    asl a
    clc
    adc #RECS
    tax
    ; w0 = b0 | b1<<8 ; a = (w0<<1)&$FFFF
    lda $0002,x
    xba
    ora $0000,x
    asl a
    sta T1
    and #$00FF
    xba
    sta DD
    lda T1
    and #$FF00
    sta DD+2
    ; w1 = b2 | b3<<8
    lda $0006,x
    xba
    ora $0004,x
    asl a
    sta T1
    and #$00FF
    xba
    sta DD+4
    lda T1
    and #$FF00
    sta DD+6
    ; group template b4 -> y = b4*32
    lda $0008,x
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc #$8615
    tax                         ; group word pointer
    ldy DOFF
    lda #16
    sta CNT
xo_w:
    lda.l $0C0000,x
    beq xo_st                   ; e == 0 -> 0
    sta T2
    and MASKD
    bne xo_m
    lda #0
    bra xo_st
xo_m:
    lda T2
    xba
    and #$0006                  ; idx*2
    phx
    tax
    lda DD,x
    plx
    cmp #$0000
    beq xo_st                   ; D == 0 -> 0
    sta T3
    bmi xo_neg
    lda T2
    and #$01FF
    ora T3
    bra xo_st
xo_neg:
    lda T3
    and #$3E00
    xba
    sta T4
    lda T3
    and #$C000
    ora T4
xo_st:
    sta [$1A],y
    inx
    inx
    iny
    iny
    dec CNT
    bne xo_w
    sty DOFF
    inc PIDX
    jmp xo_r

expand_all:
    lda #$4000
    sta $1A
    lda #$007E
    sta $1C
    lda #$85D3
    sta TBL
    lda #SLOPE
    sta ARR
    jsr expand_stream
    lda #$4C00
    sta $1A
    lda #$8591
    sta TBL
    lda #CURVE
    sta ARR
    jsr expand_stream
    jsr expand_scen
    jsr expand_objs
    rts

; ---------------------------------------------------------------------------------------------------------
; main: seed (7F:SEED) -> everything.  Call with M=X=16 bit, any DBR; clobbers A,X,Y.  Returns with RTS.
rando_generate:
    phb
    sep #$20
    lda #$7F
    pha
    plb
    rep #$30
    jsr gen_main
    plb
    rts

gen_main:
    lda SEED
    sta RS
    lda SEED+2
    sta RSH
    ora RS
    bne gm_ok
    lda #$BEEF
    sta RS
    lda #$DEAD
    sta RSH
gm_ok:
    ldx #32
gm_w:
    jsr rng_step
    dex
    bne gm_w
    lda #32
    jsr rnd
    sta ENV
    lda #23
    jsr rnd
    clc
    adc #24
    sta LEN
    inc a
    sta PN
    lda #6
    jsr rnd
    clc
    adc #3
    sta LAPS
    lda #4
    jsr rnd
    sta HILL
    lda #3
    jsr rnd
    sta CURVY
    jsr slope_walk
    jsr curve_walk
    ldx #SCEN
    jsr clear_arr
    jsr pick_source
    jsr pit_setup
    jsr expand_all
    rts

; data tables
slope_levels:   .db 1,4,3, 5,7,6, 15,17,16, 18,20,19, 21,23,22, 9,12,11, 24,26,25, 27,29,28, 30,32,31
slope_bumps:    .db 2,14,13,10
curve_levels:   .db 2,4,3, 6,8,7, 10,12,11
curve_bumps:    .db 1,17,18,19,20, 5,21,22,23,24, 9,25,26,27,28, 13,29,30,31,32
pit_styles:     .db 20,0,41, 20,1,47, 20,1,45
