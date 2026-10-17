; ============================================================================================================
; Race HUD: lap progress strip in the black bar between the two views (replaces the minimap).
;   * start line (left) and finish line (right): a BG1 tile (red line with a white border) drawn into the bar's
;     tilemap row 13 when the HUD is built (00:CBE2); the graphics go to the unused BG1 tiles $A8 (line) / $A9 (black)
;   * three dots = the game's own marker sprites (tile $7F): player 1 (red), player 2 / computer car (blue), and the
;     leader (green) unless the leader is player 1 or 2.  x = position on the lap, y = lateral position on the road.
; The usable strip is only scan lines 104..108 (BG1 tile row 13, tile rows 0..4): the game forces blank on lines 109..114
; while it swaps the palette and OAM for the second view (00:BE88..BEF4), and the second view starts at line 115.  The strip
; is made opaque black (it covers the last lines of the first view), so the black bar is 104..114.  A dot is 5 lines
; high, so the lateral position has three levels (left third, middle, right third of the road).
; ============================================================================================================
.a16
.i16

BP      = $7FF8B0               ; scratch: lap position
BL      = $7FF8B2               ; scratch: scaled lap length
BK      = $7FF8B4               ; scratch: best (lap, position) key while looking for the leader
BY      = $7FF8B6               ; scratch: car slot offset of the leader
BX      = $7FF8B8               ; scratch: dot x

BAR_X0  = 24                    ; sprite x of a dot at the start line (line = tile column 3, pixels 24..31)
BAR_W   = 200                   ; start line -> finish line (tile column 28)
BAR_Y   = 102                   ; sprite y of a dot in the middle of the strip (art rows 1..5 -> scan lines 104..108)

; ---- 00:8910 update_map_dots: the three marker words $0112 (p1), $0114 (p2), $0116 (leader) = x | y << 8 -------------
.org $008910
    jsl hook_mapdots            ; was: REP #$20 / LDA $1ED7 (5 bytes); the rest of the old routine is dead code
    rts

; ---- 01:8000 sprite_renderer writes the three marker sprites into the sprite buffers (the 00:8966/8A2C copies are not used in the race) --
; player 1's buffer keeps its three loads ($0112 / $0116 / $0114, y as is); the leader gets the player dot tile with palette 5 (green)
.org $0180A0
    lda #$3A7F                  ; was $30FF
; player 2's buffer (+$7000 on y) is parked off screen
.org $018590
    lda #$8080                  ; was LDA $0114
.org $0185A2
    lda #$8080                  ; was LDA $0116
.org $0185B4
    lda #$8080                  ; was LDA $0112

; ---- 00:CBE2 HUD tilemap: bar rows 13/14 (VRAM $0DA0..$0DDF) --------------------------------------------------------
.org $00CBE2
    jsl hook_bar                ; was: LDA #$0DA0 / STA $2116 / LDA #$AC01 / LDX #$0020 (12 bytes) and the loop of row 13
    bra $CC06                   ; skips the old row 13 loop and the row 14 setup (row 14 is written by the hook as well)
    nop
    nop
    nop
    nop
    nop
    nop

.org $128000
hook_bar:                       ; forced blank, M = X = 16 bit, VMAIN = $80
    lda #$0A80                  ; BG1 chr base 0, 4bpp: tile $A8 = word $A80, tile $A9 = word $A90
    sta.l $002116
    ldx #0
bar_hb_t:
    lda.l bar_gfx,x
    sta.l $002118
    inx
    inx
    cpx #64
    bcc bar_hb_t
    lda #$0DA0
    sta.l $002116
    ldx #0
bar_hb_13:
    lda #$2CA9                  ; solid black tile, the line tile at columns 3 and 28
    cpx #3
    beq bar_hb_13s
    cpx #28
    bne bar_hb_13w
bar_hb_13s:
    lda #$2CA8
bar_hb_13w:
    sta.l $002118
    inx
    cpx #32
    bcc bar_hb_13
    ldx #0
bar_hb_14:
    lda #$2C01
    sta.l $002118
    inx
    cpx #32
    bcc bar_hb_14
    rtl

; 4bpp tiles: $A8 = start/finish line (colour 1 = white border, 2 = black, 3 = red; pixel columns 2..5, white caps on tile rows
; 0 and 4 = the first and last visible scan line), $A9 = solid black (colour 2)
bar_gfx:
    .db $3C,$C3, $3C,$DB, $3C,$DB, $3C,$DB, $3C,$C3, $00,$FF, $00,$FF, $00,$FF
    .db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
    .db $00,$FF, $00,$FF, $00,$FF, $00,$FF, $00,$FF, $00,$FF, $00,$FF, $00,$FF
    .db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00

hook_mapdots:
    php
    rep #$30
    lda.l $001E8A
    tax
    lda.l $001ED7
    jsr bar_dot_word
    sta.l $000112               ; player 1
    lda.l $001E8C
    tax
    lda.l $001EDA
    jsr bar_dot_word
    sta.l $000114               ; player 2 / computer car
    ldx #$0012                  ; leader = highest (lap, position) key $021A over the 20 cars (same loop as the game)
    ldy #19
    lda.l $00021A
    sta.l BK
    lda #0
    sta.l BY
bar_hm_l:
    lda.l $00021A,x
    cmp.l BK
    bcc bar_hm_n
    sta.l BK
    txa
    sta.l BY
bar_hm_n:
    txa
    clc
    adc #$0012
    tax
    dey
    bne bar_hm_l
    lda.l BY
    cmp.l $000204
    beq bar_hm_h                    ; a human car leads: no third dot
    cmp.l $000206
    beq bar_hm_h
    tax
    lda.l $000214,x             ; the leader's lateral position
    pha
    lda.l $000219,x             ; and its position on the lap
    plx
    jsr bar_dot_word
    bra bar_hm_s
bar_hm_h:
    lda #$F0F0                  ; off screen
bar_hm_s:
    sta.l $000116
    plp
    rtl

bar_dot_word:                       ; A = position on the lap, X = lateral -> A = (sprite y << 8) | sprite x
    phx
    jsr bar_pos_x
    clc
    adc #BAR_X0
    sta.l BX
    pla                         ; lateral (+-0x2800 = road edges): -1 / 0 / +1 line
    bit #$8000
    bne bar_dw_n
    cmp #3413
    bcc bar_dw_0
    lda #1
    bra bar_dw_y
bar_dw_n:
    cmp #$F2AB
    bcs bar_dw_0
    lda #$FFFF
    bra bar_dw_y
bar_dw_0:
    lda #0
bar_dw_y:
    clc
    adc #BAR_Y
    xba
    and #$FF00
    ora.l BX
    rts

bar_pos_x:                          ; A = position on the lap -> A = position * BAR_W / lap length (0..BAR_W)
    sta.l BP
    lda.l $000200
    ldx #0
bar_px_s:
    cmp #$0100
    bcc bar_px_d
    lsr a
    inx
    bra bar_px_s
bar_px_d:
    cmp #$0010
    bcc bar_px_z
    sta.l BL
    lda.l BP
bar_px_p:
    cpx #0
    beq bar_px_q
    lsr a
    dex
    bra bar_px_p
bar_px_q:
    cmp #$0100
    bcc bar_px_m
    lda #$00FF
bar_px_m:
    sep #$20
    sta.l $004202               ; 8 x 8 multiply
    lda #BAR_W
    sta.l $004203
    nop
    nop
    nop
    nop
    rep #$20
    lda.l $004216
    sta.l $004204               ; 16 / 8 divide
    sep #$20
    lda.l BL
    sta.l $004206
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    rep #$20
    lda.l $004214
    cmp #BAR_W+1
    bcc bar_px_r
    lda #BAR_W
bar_px_r:
    rts
bar_px_z:
    lda #0
    rts
