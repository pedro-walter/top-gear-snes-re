; ============================================================================================================
; Top Gear (USA) randomizer - on-console track generator (65816).  Literal port of tools/trackgen.py.
; Lives in ROM bank $10.  Scratch RAM is WRAM bank $7F (never used by the game); DBR=$7F while it runs.
; M=16 bit, X=16 bit everywhere (rep #$30).  Direct page = $0000 (game's); $1A-$1C are used as a 24-bit pointer.
; ============================================================================================================
.a16
.i16

; ---- scratch variables (bank $7F; all >= $0100 so the assembler uses absolute addressing) -----------------
SEED    = $F800         ; 4 bytes   persistent seed (menu writes it)
SMODE   = $F804         ; 0 = roll a random seed on PLAY, 1 = keep the typed seed
SMAGIC  = $F806         ; $A55A once the seed area was initialised
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
ROADW   = $F87C         ; replacement bits for 00:DEE4[env] (pit road style, bits 9-11 and 15), used by hook_style
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
    lda LEN
    sec
    sbc #1
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
    ldx LEN                     ; look-ahead piece L+1 = copy of piece 1
    inx
    txa
    asl a
    tax
    lda SLOPE+2
    sta SLOPE,x
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
    lda LEN
    sec
    sbc #1
    sta END
    lda CURVY
    clc
    adc #2
    sta NLEV                    ; number of curve levels (2..4)
cw_loop:
    lda POS
    cmp END
    bcc cw_go
    ldx LEN
    inx
    txa
    asl a
    tax
    lda CURVE+2
    sta CURVE,x
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
    sta T4                      ; first byte of the two records of piece k
    tax
    lda.l $0C0000,x             ; bit 6 in b0..b3 = group object (tunnel parts): never copy such pieces
    and #$0040
    bne ps_bad
    lda.l $0C0001,x
    and #$0040
    bne ps_bad
    lda.l $0C0002,x
    and #$0040
    bne ps_bad
    lda.l $0C0003,x
    and #$0040
    bne ps_bad
    lda.l $0C0005,x
    and #$0040
    bne ps_bad
    lda.l $0C0006,x
    and #$0040
    bne ps_bad
    lda.l $0C0007,x
    and #$0040
    bne ps_bad
    lda.l $0C0008,x
    and #$0040
    bne ps_bad
    lda T4
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
    ldy LEN
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
    ; piece L: dest = RECS + 20*L
    lda LEN
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
    lda LEN
    sta END
ps_o:
    lda POS
    cmp END
    bcc ps_o2
    ; look-ahead piece L+1 = copy of piece 1
    lda SCEN+2
    ldx LEN
    inx
    txa
    asl a
    tax
    lda SCEN+2
    sta SCEN,x
    lda LEN
    inc a
    jsr rec_dest
    tay                         ; dest RECS+20*(L+1)
    ldx #0
ps_cp:
    lda RECS+20,x
    sta $0000,y
    iny
    iny
    inx
    inx
    cpx #20
    bne ps_cp
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
    sta T5
    lda CNT2
    cmp #2                      ; C = 1 for b0..b3 (object types), 0 for the template byte b4
    lda T5
    bcc c10_s
    cmp #8                      ; turn signs (8, 9) and pit signs (13) are generated, never copied
    beq c10_z
    cmp #9
    beq c10_z
    cmp #13
    beq c10_z
    phx
    pha
    lda ENV
    asl a
    asl a
    tax
    pla
    sep #$20
    cmp.l dropt,x
    beq c10_zx
    cmp.l dropt+1,x
    beq c10_zx
    cmp.l dropt+2,x
    beq c10_zx
    cmp.l dropt+3,x
    beq c10_zx
    rep #$20
    plx
    bra c10_s
c10_zx:
    rep #$20
    plx
c10_z:
    lda #0
c10_s:
    sta $0000,y
    inx
    iny
    iny
    dec CNT2
    bne c10
    rts

; ---------------------------------------------------------------------------------------------------------
; pit
write_flag:                     ; A = template byte, Y = destination of a piece's 2 records (advanced by 20): sign type 13 in b0 or b1 (T5)
    sta T0
    lda #2
    sta CNT2
wf_l:
    lda #0
    sta $0000,y
    sta $0002,y
    sta $0004,y
    sta $0006,y
    lda T0
    sta $0008,y
    lda T5
    bne wf_b1
    lda #13
    sta $0000,y
    bra wf_d
wf_b1:
    lda #13
    sta $0002,y
wf_d:
    tya
    clc
    adc #10
    tay
    dec CNT2
    bne wf_l
    rts

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
    asl a
    asl a
    asl a
    tax                         ; style*8: template, side, group, flag far, flag near, flag slot, road style, mirror
    lda PP
    asl a
    tay
    lda.l pit_styles,x
    and #$00FF
    sta SCEN,y
    lda.l pit_styles+1,x
    and #$00FF
    sta T1                      ; side
    lda.l pit_styles+2,x
    and #$00FF
    sta T2                      ; group
    lda.l pit_styles+3,x
    and #$00FF
    sta T3                      ; flag template, 2 pieces before the pit
    lda.l pit_styles+4,x
    and #$00FF
    sta T4                      ; flag template, piece before the pit
    lda.l pit_styles+5,x
    and #$00FF
    sta T5                      ; 0: sign type in b0, 1: in b1
    lda.l pit_styles+6,x
    and #$00FF
    xba
    asl a                       ; road style << 9
    sta ROADW
    lda.l pit_styles+7,x
    and #$00FF
    beq pm_0
    lda ROADW
    ora #$8000
    sta ROADW
pm_0:
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
    ; pit flags (object type 13) on the two pieces before the pit
    lda PP
    dec a
    dec a
    jsr rec_dest
    tay
    lda T3
    jsr write_flag
    lda T4
    jsr write_flag
    ; the last piece before the start line stays empty (the start gantry needs it)
    lda LEN
    dec a
    jsr rec_dest
    tay
    ldx #10
    lda #0
zl_l:
    sta $0000,y
    iny
    iny
    dex
    bne zl_l
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

edge_get:                       ; A = signed drawn road edge for slot T5 on the side of T3 (bit 8 set = left)
    lda T5
    asl a
    tax
    lda.l $7E5800,x             ; scenery word -> road type -> road style -> drawn edge; the sign sits 44 units outside it
    and #$7FFE
    tax
    lda.l $009B3F,x             ; 4 * road type
    lsr a
    lsr a
    sta CNT2
    asl a
    clc
    adc CNT2
    sta CNT2                    ; 3 * road type = shift of the style in the style word
    lda ENV
    asl a
    tax
    lda.l $00DEE4,x
    and #$71FF
    ora.l $7FF87C               ; ROADW
    ldx CNT2
    beq ac_s0
ac_sh:
    lsr a
    dex
    bne ac_sh
ac_s0:
    and #7
    asl a
    asl a                       ; 4 bytes per style: left edge, right edge
    tax
    lda T3
    and #$0100
    bne ac_lf
    inx
    inx
ac_lf:
    lda.l $00C592,x
    rts

add_chevrons:                   ; turn signs: one chevron every 4 slots from 20 slots before a curve onset to the end of the curve
    lda LEN
    asl a
    asl a
    asl a
    asl a
    asl a
    sta LIM                     ; L*32 slots per lap
    lda #24
    sta T0                      ; slot i
ac_i:
    lda T0
    cmp LIM
    bcc ac_go
    jmp ac_done
ac_go:
    asl a
    tax
    lda.l $7E4C00,x             ; b = curve[i]
    sta T1
    lda.l $7E4BFE,x             ; a = curve[i-1]
    sta T2
    lda T1
    bpl ac_bp
    eor #$FFFF
    inc a
ac_bp:
    cmp #8
    bcc ac_next
    lda T2
    bpl ac_ap
    eor #$FFFF
    inc a
ac_ap:
    cmp #8
    bcc ac_onset
    lda T1
    eor T2
    bpl ac_next                 ; same direction: not an onset
ac_onset:
    lda T1
    bmi ac_neg
    lda #$127C                  ; type 9 ('<'), right side, lateral 124
    bra ac_w
ac_neg:
    lda #$117C                  ; type 8 ('>'), left side
ac_w:
    sta T3
    lda T0
    sta CNT                     ; e = end of the curve
ac_e:
    lda CNT
    inc a
    cmp LIM
    bcs ac_ed
    asl a
    tax
    lda.l $7E4C00,x
    sta T6
    bpl ac_ep
    eor #$FFFF
    inc a
ac_ep:
    cmp #8
    bcc ac_ed
    lda T6
    eor T1
    bmi ac_ed
    inc CNT
    bra ac_e
ac_ed:
    lda T0
    sec
    sbc #20
    sta T5                      ; slot j
ac_kl:
    lda CNT
    cmp T5
    bcc ac_fin                  ; e < j
    lda T5
    cmp #48
    bcc ac_skip                 ; no signs near the start gantry (graphics conflict)
    lda LIM
    sec
    sbc #48
    cmp T5
    bcc ac_skip
    beq ac_skip
    lda T5
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a                       ; piece of slot j
    sta T6
    sec
    sbc PP
    clc
    adc #2
    cmp #3
    bcc ac_skip                 ; pieces PP-2..PP keep their own objects (pit flags, pit lane)
    lda T6
    inc a
    cmp LEN
    beq ac_skip                 ; the last piece stays empty
    lda T5
    asl a
    tax
    lda.l $7E6400,x
    bmi ac_skip                 ; group objects
    and #$FE00
    cmp #$7400
    beq ac_skip                 ; pit entrance
    jsr edge_get
    bpl ac_ep2
    eor #$FFFF
    inc a
ac_ep2:
    clc
    adc #44
    cmp #256
    bcc ac_ok
    lda #255
ac_ok:
    sta CNT2
    lda T3
    and #$FF00
    ora CNT2
    pha
    lda T5
    asl a
    tax
    pla
    sta.l $7E6400,x
ac_skip:
    lda T5
    clc
    adc #4
    sta T5
    bra ac_kl
ac_fin:
    lda CNT
    inc a
    sta T0
    jmp ac_i
ac_next:
    inc T0
    jmp ac_i
ac_done:                        ; roadside trees/bushes in the gaps: every 8 slots from 52, alternating sides, 60 units outside the edge
    lda ENV
    asl a
    tax
    lda.l scent,x
    and #$00FF
    beq ac_copy
    sta T1                      ; type A (2 of 3 slots)
    lda.l scent,x
    xba
    and #$00FF
    sta T2                      ; type B (every third slot)
    stz T0                      ; (j >> 3) mod 3, j = 52 -> 6 mod 3 = 0
    lda #52
    sta T5
as_l:
    lda LIM
    sec
    sbc #48
    cmp T5
    bcc ac_copy
    beq ac_copy
    lda T5
    asl a
    tax
    lda.l $7E6400,x
    bne as_next
    lda T5
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a
    sta T6                      ; piece of slot j
    sec
    sbc PP
    clc
    adc #2
    cmp #3
    bcc as_next                 ; pit pieces keep their own objects
    lda T6
    inc a
    cmp LEN
    beq as_next                 ; the last piece stays empty
    lda T5
    and #$0008
    beq as_s0
    lda #$0100
as_s0:
    sta T3                      ; side bit (1 = left)
    lda T0
    beq as_tb
    lda T1
    bra as_ty
as_tb:
    lda T2
as_ty:
    xba
    asl a                       ; type << 9
    ora T3
    sta T4
    jsr edge_get
    bpl as_ep
    eor #$FFFF
    inc a
as_ep:
    clc
    adc #60
    cmp #256
    bcc as_ok
    lda #255
as_ok:
    ora T4
    pha
    lda T5
    asl a
    tax
    pla
    sta.l $7E6400,x
as_next:
    inc T0
    lda T0
    cmp #3
    bcc as_t
    stz T0
as_t:
    lda T5
    clc
    adc #8
    sta T5
    bra as_l
ac_copy:                        ; pieces L, L+1 are copies of 0, 1
    lda #$6400
    sta $1A
    lda #$007E
    sta $1C
    lda LIM
    asl a
    tay
    ldx #0
ac_c:
    lda.l $7E6400,x
    sta [$1A],y
    inx
    inx
    iny
    iny
    cpx #128
    bne ac_c
    rts

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
    jsr add_chevrons
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

gen_init:                       ; RNG state from the seed (+32 warm-up steps)
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
    rts

rando_env:                      ; computes only the first three draws -> ENV, LEN, PN, LAPS.  Same calling convention as rando_generate
    phb
    sep #$20
    lda #$7F
    pha
    plb
    rep #$30
    jsr gen_init
    jsr draw_basic
    plb
    rts

draw_basic:
    lda #32
    jsr rnd
    sta ENV
    lda #23
    jsr rnd
    clc
    adc #24
    sta LEN
    inc a
    inc a
    sta PN
    lda #6
    jsr rnd
    clc
    adc #3
    sta LAPS
    rts

gen_main:
    jsr gen_init
    jsr draw_basic
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
scent:          .db 27,27,24,27,0,0,24,15,27,15,27,26,27,14,15,27,0,0,27,27,27,15,15,14,24,56,15,15,0,0,24,27,25,31,27,25,15,14,31,15,27,24,24,57,27,15,27,26,26,56,27,26,15,27,24,27,27,24,27,15,27,25,27,27
dropt:          .db 28,38,0,0, 15,0,0,0, 11,12,42,0, 11,41,0,0, 14,0,0,0, 24,0,0,0, 15,28,0,0, 24,0,0,0, 55,0,0,0, 54,55,15,0, 43,0,0,0, 0,0,0,0, 27,0,0,0, 10,0,0,0, 31,0,0,0, 11,12,26,0, 27,0,0,0, 31,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 27,7,0,0, 0,0,0,0, 0,0,0,0, 27,0,0,0, 24,0,0,0, 0,0,0,0, 25,0,0,0, 14,0,0,0, 30,0,0,0, 15,29,0,0, 15,14,0,0
pit_styles:     .db 20,0,41,24,24,0,1,0, 20,1,45,26,26,0,4,0, 20,1,47,24,26,1,5,1
