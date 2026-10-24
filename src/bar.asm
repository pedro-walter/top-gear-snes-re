; ============================================================================================================
; Race HUD: lap progress strip in the black bar between the two views (replaces the minimap).
;   * start line (left) and finish line (right): a BG1 tile (white / red / white, lines 106..108) at columns 3 and 28 of the bar's
;     tilemap row 13 when the HUD is built (00:CBE2); the graphics go to the unused BG1 tile $A8 ($A9 = spare black)
;   * three dots = the game's own marker sprites, with the tile $7F redrawn as a small 4x1 dash with black ends (the tiles $7F/$FF are only
;     used by these markers): player 1 (upper lane, line 106), the leader (middle lane, 107, unless player 1 or 2 leads) and player 2 /
;     the computer car (lower lane, 108).  x = position on the lap.  The colours are the car's own sprite palette: players 0 / 1 as in the
;     original, the leader the palette of its car (record word >> 13 & 3), colour 9 of the palette.
; The original divider (lines 108..115) and the whole first view are untouched: the game forces blank on lines 109..114 while it swaps the
; palette and OAM for the second view (00:BE88..BEF4), so nothing can be drawn there; the only visible divider lines are 108 and 115.
; So the strip is drawn over the last three lines of the first view (106..108) and has no background of its own.
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
BAR_Y1  = 105                   ; sprite y of the player 1 lane (art row 0 -> scan line 106)
BAR_YL  = 106                   ; leader lane (line 107)
BAR_Y2  = 107                   ; player 2 lane (line 108)
LCB     = $7FF900               ; scratch: the lap counter cells (up to 9 words)
LAPV    = $7FF920               ; scratch: lap shown
TOTV    = $7FF922               ; scratch: laps of the race
LCN     = $7FF924               ; scratch: bytes in LCB

BAR_ATTR = $001FB2              ; the leader's tile | attribute word (unused lap-record RAM in the race)

; ---- 00:8910 update_map_dots: the three marker words $0112 (p1), $0114 (p2), $0116 (leader) = x | y << 8 -------------
.org $008910
    jsl hook_mapdots            ; was: REP #$20 / LDA $1ED7 (5 bytes); the rest of the old routine is dead code
    rts

; ---- 01:8000 sprite_renderer writes the three marker sprites into the sprite buffers (the 00:8966/8A2C copies are not used in the race) --
; player 1's buffer keeps its three loads ($0112 / $0116 / $0114, y as is); the leader's tile / attribute word comes from hook_mapdots
.org $0180A0
    lda $1FB2                   ; was $30FF: the leader's tile | palette
; player 2's buffer (+$7000 on y) is parked off screen
.org $018590
    lda #$8080                  ; was LDA $0114
.org $0185A2
    lda #$8080                  ; was LDA $0116
.org $0185B4
    lda #$8080                  ; was LDA $0112

; ---- 00:CE61 draw_hud_speed (called every frame with VRAM writable): the lap counters under the timers ---------------------------------
.org $00CE61
    jsl hook_lapctr             ; was: REP #$30 / LDA $1E5A (5 bytes); the hook ends with that LDA (the BPL behind it uses its flags)
    nop

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
    cpx #96
    bcc bar_hb_t
    lda #$27F0                  ; sprite tile $7F (table at byte $4000): the dot
    sta.l $002116
    ldx #0
bar_hb_d:
    lda.l bar_dot,x
    sta.l $002118
    inx
    inx
    cpx #32
    bcc bar_hb_d
    lda #$0B00                  ; BG1 tiles $B0..$B2: L, P and the slash (the digits and the A are the HUD font's own tiles)
    sta.l $002116
    ldx #0
bar_hb_f:
    lda.l bar_font,x
    sta.l $002118
    inx
    inx
    cpx #96
    bcc bar_hb_f
    ; BX = tile column of the pit (none: no pit lane on this track, $1EF0 >= lap length)
    ldy #$FFFF
    lda.l $7FF83E               ; the generator's pit word (PITW; $1EF0 is not loaded yet when the HUD is built) = side << 15 | position / 2
    and #$7FFF
    asl a
    cmp.l $000200
    bcs bar_hb_np
    jsr bar_pos_x               ; position -> 0..BAR_W pixels, same scale as the dots
    clc
    adc #BAR_X0
    lsr a
    lsr a
    lsr a
    tay
bar_hb_np:
    tya
    sta.l BX
    lda #$0DA0
    sta.l $002116
    ldx #0
bar_hb_13:
    lda #$AC01                  ; the original filler
    cpx #3
    beq bar_hb_13s
    cpx #28
    beq bar_hb_13s              ; start / finish line tile
    txa
    cmp.l BX                    ; pit column?
    beq bar_hb_13p
    lda #$AC01
    bra bar_hb_13w
bar_hb_13p:
    lda #$2CAA                  ; pit marker tile
    bra bar_hb_13w
bar_hb_13s:
    lda #$2CA8
bar_hb_13w:
    sta.l $002118
    inx
    cpx #32
    bcc bar_hb_13
    ldx #0
bar_hb_14:
    lda #$2C01                  ; the original filler of row 14
    sta.l $002118
    inx
    cpx #32
    bcc bar_hb_14
    rtl

; 4bpp tiles: $A8 = start/finish line (colour 1 = white border, 2 = black, 3 = red; pixel columns 2..5, white caps on tile rows
; 0 and 4 = the first and last visible scan line), $A9 = solid black (colour 2)
bar_gfx:
    .db $00,$00, $00,$00, $3C,$00, $3C,$18, $3C,$C3, $00,$FF, $00,$FF, $00,$FF
    .db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
    .db $00,$FF, $00,$FF, $00,$FF, $00,$FF, $00,$FF, $00,$FF, $00,$FF, $00,$FF
    .db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
; $AA = pit marker: black box on the three strip lines (colour 2) with a white dash (colour 1) in the middle line
    .db $00,$00, $00,$00, $00,$FF, $3C,$C3, $00,$FF, $00,$00, $00,$00, $00,$00
    .db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00

bar_dot:                        ; 4bpp: row 0 = black end pixels (colour 6: planes 1+2) around 4 pixels of colour 9 (planes 0+3)
    .dw $423C,0,0,0,0,0,0,0
    .dw $3C42,0,0,0,0,0,0,0

hook_mapdots:
    php
    rep #$30
    ldx #BAR_Y1
    lda.l $001ED7
    jsr bar_dot_word
    sta.l $000112               ; player 1
    ldx #BAR_Y2
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
    beq bar_hm_h                ; a human car leads: no third dot
    cmp.l $000206
    beq bar_hm_h
    tax
    lda.l $000212,x             ; the leader's sprite palette code (bits 13/14 of the record word)
    xba
    lsr a
    lsr a
    lsr a
    lsr a
    and #$0006                  ; = palette << 1
    ora #$307F                  ; priority 3, tile $7F
    sta.l BAR_ATTR
    lda.l $000219,x             ; its position on the lap
    ldx #BAR_YL
    jsr bar_dot_word
    bra bar_hm_s
bar_hm_h:
    lda #$F0F0                  ; off screen
bar_hm_s:
    sta.l $000116
    plp
    rtl

bar_dot_word:                   ; A = position on the lap, X = sprite y -> A = (sprite y << 8) | sprite x
    phx
    jsr bar_pos_x
    clc
    adc #BAR_X0
    sta.l BX
    pla
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

; 4bpp tiles $B0..$B2 (tools/lapfont.py): L, P, '/' drawn like the timer font's R (same colours), palette 3 of BG1; the digits are the HUD's
; tiles $35.. (the timer's) and the A is $4B
bar_font:
    .db $00,$00,$00,$E0,$10,$90,$10,$90,$10,$90,$02,$82,$03,$83,$7E,$7E   ; 'L'
    .db $00,$00,$00,$E0,$60,$F0,$60,$F0,$60,$F0,$7C,$FE,$7C,$FF,$00,$7E
    .db $00,$00,$00,$F8,$02,$82,$19,$99,$03,$83,$1E,$9E,$10,$90,$30,$30   ; 'P'
    .db $00,$00,$00,$F8,$7C,$FE,$66,$FF,$7C,$FF,$60,$FE,$60,$F0,$00,$30
    .db $00,$00,$00,$1C,$02,$12,$04,$24,$04,$24,$08,$48,$08,$48,$30,$30   ; '/'
    .db $00,$00,$00,$1C,$0C,$1E,$18,$3C,$18,$3C,$30,$78,$30,$78,$00,$30

; ---- lap counters: "LAP lap/laps" right aligned to tile column 29 of the row under each timer (rows 5 and 19; the fuel gauge is column 30
; and starts a row lower; "LAP 3/7" is as wide as the timer, columns 23..29) -------------------------------------------------------------------------------------------------------
; $1E76 / $1E78 = laps completed by player 1 / player 2 (the computer in one player mode): $FFFF while the car is still behind the line
; of lap 1; the lap shown is that + 1 (at least 1, at most the number of laps).
hook_lapctr:
    rep #$30
    sep #$20
    lda #$80
    sta.l $002115               ; VMAIN: word increment
    rep #$20
    lda.l $001E76
    ldx #$0CB6                  ; $0C00 + 5 * 32 + 22 (first of 8 cells; column 21 belongs to the messages, e.g. the T of LAPS LEFT)
    jsr bar_lc_draw
    lda.l $001E78
    ldx #$0E76                  ; $0C00 + 19 * 32 + 22
    jsr bar_lc_draw
    rep #$30
    lda.l $001E5A               ; the instruction this hook replaces: the caller branches on its flags
    rtl

bar_lc_draw:                    ; A = laps completed, X = VRAM word of the first cell
    phx
    cmp #$8000
    bcc bar_ld_p
    lda #0
bar_ld_p:
    inc a
    sta.l LAPV
    lda.l $001E56
    sta.l TOTV
    lda.l LAPV
    cmp.l TOTV
    bcc bar_ld_o
    lda.l TOTV
    sta.l LAPV
bar_ld_o:
    lda #$2CB0                  ; L
    sta.l LCB
    lda #$2C4B                  ; A
    sta.l LCB+2
    lda #$2CB1                  ; P
    sta.l LCB+4
    lda #0
    sta.l LCB+6                 ; blank
    ldx #8
    lda.l LAPV
    jsr bar_lc_num
    lda #$2CB2                  ; the slash
    sta.l LCB,x
    inx
    inx
    lda.l TOTV
    jsr bar_lc_num
    txa
    sta.l LCN
    pla
    sta.l $002116
    lda #16
    sec
    sbc.l LCN                   ; blank cells in front = 8 - cells (the counter is at most 'LAP 8/8' = 7 cells)
    lsr a
    tax
    beq bar_ld_w
bar_ld_b:
    lda #0
    sta.l $002118
    dex
    bne bar_ld_b
bar_ld_w:
    ldx #0
bar_ld_l:
    txa
    cmp.l LCN
    bcs bar_ld_x
    lda.l LCB,x
    sta.l $002118
    inx
    inx
    bra bar_ld_l
bar_ld_x:
    rts

bar_lc_num:                     ; A = number (< 100), X = index into LCB: appends its digits as tile words, X advances
    ldy #0
bar_ln_t:
    cmp #10
    bcc bar_ln_d
    sbc #10
    iny
    bra bar_ln_t
bar_ln_d:
    pha
    cpy #0
    beq bar_ln_o
    tya
    clc
    adc #$2C35
    sta.l LCB,x
    inx
    inx
bar_ln_o:
    pla
    clc
    adc #$2C35
    sta.l LCB,x
    inx
    inx
    rts
