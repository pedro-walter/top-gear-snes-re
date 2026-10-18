; ============================================================================================================
; Patches into the original game code + (test build only) a harness that runs the generator in a loop.
; ============================================================================================================
.a16
.i16

; ---- 00:BF59  inside load_track_streams: skip the stream expansion, generate the track instead ----------
.org $00BF59
    jml hook_streams            ; was: REP #$30 / LDA $1F06   (5 bytes)
    nop

; ---- 00:BF38  end of load_track: laps ------------------------------------------------------------------
.org $00BF38
    jml hook_laps               ; was: LDA $1F06 / ASL / TAX / LDA $DEA4,X / STA $1E56 / RTS

; ---- 00:C270  load_road_graphics: the pit lane's road style (type 3) and mirror bit come from the generator --------
.org $00C270
    jml hook_style              ; was: LDA $DEE4,X / STA $1A   (5 bytes)
    nop

; ---- 00:C162  end of load_track_streams: pit position / side ------------------------------------------
.org $00C162
    jml hook_pit

.org $10F000
hook_streams:                   ; stack holds the caller's DBR (PHB at BF46), restored by PLB at 00:C0F1
    rep #$30
    jsr rando_generate
    lda.l $7FF830               ; ENV -> track id (all per-track tables of the game keep working)
    sta.l $001F06
    lda.l $7FF832               ; LEN pieces -> track length in position units
    xba
    asl a
    asl a
    sta.l $000200
    jml $00C0F1

hook_style:
    lda.l $00DEE4,x
    and #$71FF                  ; clear the type-3 style (bits 9-11) and the mirror bit (15)
    ora.l $7FF87C               ; ROADW
    sta $1A
    jml $00C275                 ; BPL (N from the ORA)

hook_laps:
    rep #$30
    lda.l $7FF836
    sta.l $001E56
    jml $00BF43                 ; the RTS of load_track

hook_pit:
    rep #$30
    lda.l $7FF83E
    bpl hp_clr
    lda #$0004
    tsb $1EF2
    bra hp_pos
hp_clr:
    lda #$0004
    trb $1EF2
hp_pos:
    lda.l $7FF83E
    and #$7FFF
    asl a
    sta $1EF0
    jml $00C181                 ; the RTS of load_track_streams

; ---- 0F:9281  main menu, PLAY GAME chosen: (re)roll the seed, derive the environment ------------------------
.org $0F9281
    jml hook_play               ; was: LDA $1F04 / BNE $9294 (5 bytes, the 5th is unreachable)

; ---- 0F:8487  results screen finished: back to the title/main menu instead of the championship flow ---------
.org $0F8487
    jml hook_afterresults       ; was: SEP #$20 / LDA #$10 / ... championship flow

.org $10F100
seed_init:                      ; first use after power-on: default seed, random mode
    lda.l $7FF806
    cmp #$A55A
    beq si_ok
    lda #$A55A
    sta.l $7FF806
    lda #$0000
    sta.l $7FF804
    sta.l SKIPT
    lda #$1234
    sta.l $7FF800
    lda #$5678
    sta.l $7FF802
    jsr roll_seed
si_ok:
    rts

roll_seed:                      ; new random seed: entropy (H/V counters = reaction time, the game's RNG words) mixed into the old seed,
    sep #$20                    ; then scrambled by LFSR bursts and additions so that every digit changes
    lda.l $002137
    lda.l $00213C
    xba
    lda.l $00213D
    rep #$20
    eor.l $001FF4
    clc
    adc.l $001FFC
    eor.l $7FF800
    sta.l $7FF810
    lda.l $001FF4
    asl a
    asl a
    eor.l $001FFC
    eor.l $001FF8
    clc
    adc.l $001FFA
    eor.l $7FF802
    sta.l $7FF812
    phb
    sep #$20
    lda #$7F
    pha
    plb
    rep #$30
    lda RS
    ora RSH
    bne rl_nz
    lda #$A5C3
    sta RS
rl_nz:
    ldx #4
rl_r:
    ldy #13
rl_s:
    jsr rng_step
    dey
    bne rl_s
    lda RS
    clc
    adc RSH
    sta RS
    lda RSH
    eor RS
    sta RSH
    dex
    bne rl_r
    lda RS
    sta SEED
    lda RSH
    sta SEED+2
    plb
    rts

hook_play:
    rep #$30
    jsr seed_init
    ldx #$0012
hp_zero:                        ; the points table ($1F4E..) is per race now
    stz $1F4E,x
    dex
    dex
    bpl hp_zero
    jsr rando_env
    lda.l $7FF830               ; ENV -> track id for splash screen, music and per-track tables
    sta.l $001F06
hp_l:
    lda $1F04
    bne hp_ret
    lda $1FFC
    and #$0003
    cmp $1F8F
    beq hp_l
    sta $1FAC
hp_ret:
    jml $0F9294                 ; the RTS of main_menu

; ===========================================================================================================
; Menu glue.  The menu code is JSR based (bank $0F); bank-$0F stubs below are near-call trampolines so that my
; bank-$10 code can call it with JSL.  DBR is $0F while the menus run, WRAM is reached with long addressing.
; ===========================================================================================================
SDL     = $7FF800               ; seed low word          (see gen.asm)
SDH     = $7FF802               ; seed high word
SFLAG   = $7FF808               ; 1 while the hex keypad is active
SKIPT   = $7FF80A               ; 1: skip the title screen once (after the results)
V_DST   = $7FF8A0
V_LO    = $7FF8A2
V_HI    = $7FF8A4
V_T     = $7FF8A6
STR1    = $1FB2                 ; low RAM scratch for strings: the lap-record table ($1FB2..$1FF1) is unused now

.org $0FFB00
t_fadeout:  jsr $9DC5
    rtl
t_fadein:   jsr $9DB2
    rtl
t_font:     jsr $9E1C
    rtl
t_page:     jsr $9C31
    rtl
t_dsb:      jsr $9F93
    rtl
t_dstr:     jsr $9F3E
    rtl
t_list:     jsr $9ED0
    rtl
t_bar:      jsr $A045
    rtl
t_cur:      jsr $9B56
    rtl
t_oam:      jsr $9DDD
    rtl
t_text:     jsr $943D
    rtl
t_9dfc:     jsr $9DFC
    rtl
t_cleartext: jsr $8F80
    rtl
t_vbl:      jsr $A24D
    rtl
t_seedmenu: jml seed_menu       ; target of the patched "JMP country_menu"

; ---- main menu entry 2: COUNTRY -> SEED -----------------------------------------------------------------
.org $0F9295
    jmp t_seedmenu              ; was: JMP country_menu

.org $0F91A0
    jsl hook_menu_draw          ; was: STZ $5A / LDY $1FB0 (5 bytes)
    nop

.org $0FA6CD
    .db "SEED   "               ; label "COUNTRY" of main menu entry 2
.org $0FA725
    .dw $0009                   ; $A721[2]: highlight bar length of entry 2 (was 8): ends right after the seed digits

; ---- hex keypad: the password page (8) is reused (passwords do not exist any more) --------------------------
.org $0FA9E0
    .db $08,$03,"SEED    ",0
    .db 0,0                     ; end of list (the original password grid strings are not drawn: src/keypad.asm draws the keys)

; ---- splash (location) screen ------------------------------------------------------------------------------
.org $0FABE9
    .db $0D,$02,"  SEED  ",0
    .db $12,$09,"STATISTICS",0
    .db $13,$0C,"DISTANCE",0
    .db $12,$10,"          ",0
    .db $15,$14,"LAPS",0
    .db $05,$09,"     ",0

.org $0F81AB
    jsl hook_loc                ; was: LDA $1F06 / ASL / TAX / LDA $0DC77C,X / TAX / JSR sub_0F9ED0  (13 bytes)
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
.org $0F8AC9
    jsl hook_laps8              ; was: LDX $1F06 / LDA $0DC6D6,X   (laps digit)
    nop
    nop
    nop
.org $0F8B08
    jsl hook_dist               ; was: LDX $1F06 / LDA $0DC6F6,X   (distance = pieces)
    nop
    nop
    nop
.org $0FAC82
    .db $1F                     ; lap-record value template: row 0x12 -> off screen
.org $0F8232
    jsl hook_blankmap           ; was: LDA #$800D / LDY #0 / JSR decompress_to_wram (9 bytes): minimap bitmap -> blank
    nop
    nop
    nop
    nop
    nop

; ---- race HUD: minimap marker sprites off ----------------------------------------------------------------------
; (the routines stay alive: draw_map_dots_p1 also derives the pit scene's BG scroll $A6 - only the dot positions are parked)
.org $0089BE
    lda #$F0F0                  ; was LDA $0112
.org $0089CC
    lda #$F0F0                  ; was LDA $0116
.org $0089DA
    lda #$F0F0                  ; was LDA $0114
.org $008A84
    lda #$8080                    ; was LDA $0114 (the p2 routine adds $7000)
.org $008A96
    lda #$8080                    ; was LDA $0116
.org $008AA8
    lda #$8080                    ; was LDA $0112

; ===========================================================================================================
; bank $10 menu code
; ===========================================================================================================
.org $10F300
hex_table:
    .db "0123456789ABCDEF"
    .db 0,0,0,0,0,0,0,0,0,0,0,0,0,0

hexdig:                         ; A = 0..15 -> ASCII
    and #$000F
    clc
    adc #$0030
    cmp #$003A
    bcc hd_ok
    adc #$0006
hd_ok:
    rts

build_seed_str:                 ; X = destination (bank 0 RAM): the 8 hex digits of the seed
    txa
    sta.l V_DST
    lda.l SDL
    sta.l V_LO
    lda.l SDH
    sta.l V_HI
    ldy #0
bs_l:
    lda.l V_HI
    xba
    lsr a
    lsr a
    lsr a
    lsr a
    jsr hexdig
    sta.l V_T
    tya
    clc
    adc.l V_DST
    tax
    sep #$20
    lda.l V_T
    sta.l $000000,x
    rep #$20
    ldx #4
bs_sh:
    lda.l V_LO
    asl a
    sta.l V_LO
    lda.l V_HI
    rol a
    sta.l V_HI
    dex
    bne bs_sh
    iny
    cpy #8
    bne bs_l
    rts

SBV     = $7FF8C0               ; scratch: glyph number while the shifted seed tiles are built
SBB     = $7FF8D0               ; scratch: offset of the glyph in seed_glyphs

build_seed_tiles:               ; main menu draw: the 16 hex digit glyphs of the small font (seed_glyphs) shifted down
                                ; 4 lines into two tiles each: upper = BG1 tile $40+2v, lower = $41+2v (VRAM word $1400.., free), so the seed is
                                ; vertically centred in the 16 line selector bar
    sep #$20
    stz $4200
    lda #$80
    sta $2100
    sta $2115
    rep #$20
    lda #0
    sta.l SBV
bst_g:
    lda.l SBV
    asl a
    asl a
    asl a
    asl a
    asl a
    sta.l SBB                   ; offset of the glyph in seed_glyphs
    lda.l SBV
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc #$1400
    sta.l $002116
    ldy #0
bst_u:                          ; upper tile: rows 0..3 empty, rows 4..7 = glyph rows 0..3 (per bitplane pair)
    tya
    and #7
    cmp #4
    bcc bst_uz
    tya
    sec
    sbc #4
    asl a
    clc
    adc.l SBB
    tax
    lda.l seed_glyphs,x
    bra bst_uw
bst_uz:
    lda #0
bst_uw:
    sta.l $002118
    iny
    cpy #16
    bcc bst_u
    ldy #0
bst_d:                          ; lower tile: rows 0..3 = glyph rows 4..7, rows 4..7 empty
    tya
    and #7
    cmp #4
    bcs bst_dz
    tya
    clc
    adc #4
    asl a
    clc
    adc.l SBB
    tax
    lda.l seed_glyphs,x
    bra bst_dw
bst_dz:
    lda #0
bst_dw:
    sta.l $002118
    iny
    cpy #16
    bcc bst_d
    lda.l SBV
    inc a
    sta.l SBV
    cmp #16
    bcc bst_g
    sep #$20
    lda #$81
    sta $4200                   ; NMI + joypad again
    rep #$20
    rts

seed_glyphs:                    ; the 16 hex digit glyphs of the game's small font (4bpp tiles, 32 bytes each, 0..F; copied from the
                                ; font in VRAM: it is not loaded yet when the menu comes back from a race)
    .db $3C,$02,$66,$19,$46,$31,$C6,$21,$C6,$21,$CC,$23,$78,$86,$00,$3C
    .db $02,$00,$19,$00,$31,$00,$21,$00,$21,$00,$23,$00,$86,$00,$3C,$00   ; '0'
    .db $18,$04,$38,$04,$18,$04,$30,$0C,$30,$08,$60,$18,$60,$10,$00,$70
    .db $04,$00,$04,$00,$04,$00,$0C,$00,$08,$00,$18,$00,$10,$00,$70,$00   ; '1'
    .db $3C,$02,$66,$19,$66,$11,$0C,$73,$38,$06,$70,$0C,$FC,$02,$00,$FE
    .db $02,$00,$19,$00,$11,$00,$73,$00,$06,$00,$0C,$00,$02,$00,$FE,$00   ; '2'
    .db $3C,$02,$66,$19,$06,$71,$1C,$03,$0C,$12,$CC,$02,$78,$86,$00,$7C
    .db $02,$00,$19,$00,$71,$00,$03,$00,$12,$00,$02,$00,$86,$00,$7C,$00   ; '3'
    .db $1E,$01,$36,$09,$64,$13,$CC,$32,$FE,$01,$18,$E7,$18,$04,$00,$1C
    .db $01,$00,$09,$00,$13,$00,$32,$00,$01,$00,$E7,$00,$04,$00,$1C,$00   ; '4'
    .db $3E,$01,$30,$0F,$70,$08,$7C,$02,$06,$79,$CE,$01,$7C,$83,$00,$7E
    .db $01,$00,$0F,$00,$08,$00,$02,$00,$79,$00,$01,$00,$83,$00,$7E,$00   ; '5'
    .db $1C,$02,$36,$09,$60,$1F,$7C,$02,$E6,$19,$CE,$31,$7C,$83,$00,$7E
    .db $02,$00,$09,$00,$1F,$00,$02,$00,$19,$00,$31,$00,$83,$00,$7E,$00   ; '6'
    .db $7C,$02,$0C,$72,$18,$06,$30,$0C,$70,$08,$E0,$18,$E0,$10,$00,$F0
    .db $02,$00,$72,$00,$06,$00,$0C,$00,$08,$00,$18,$00,$10,$00,$F0,$00   ; '7'
    .db $1C,$02,$36,$09,$66,$19,$7E,$01,$EC,$13,$CC,$22,$78,$86,$00,$7C
    .db $02,$00,$09,$00,$19,$00,$01,$00,$33,$00,$22,$00,$86,$00,$7C,$00   ; '8'
    .db $3C,$02,$66,$19,$66,$11,$3E,$41,$0C,$33,$CC,$02,$78,$86,$00,$7C
    .db $02,$00,$19,$00,$11,$00,$41,$00,$33,$00,$02,$00,$86,$00,$7C,$00   ; '9'
    .db $1C,$02,$3E,$01,$36,$09,$66,$19,$7E,$01,$C6,$39,$C6,$21,$00,$E7
    .db $02,$00,$01,$00,$09,$00,$19,$00,$01,$00,$39,$00,$21,$00,$E7,$00   ; 'A'
    .db $3C,$02,$36,$09,$66,$11,$7C,$03,$EC,$12,$CC,$22,$F8,$06,$00,$FC
    .db $02,$00,$19,$00,$11,$00,$03,$00,$32,$00,$22,$00,$06,$00,$FC,$00   ; 'B'
    .db $1C,$02,$36,$09,$60,$1F,$60,$10,$C0,$30,$CC,$22,$F8,$06,$00,$FC
    .db $02,$00,$09,$00,$1F,$00,$10,$00,$30,$00,$22,$00,$06,$00,$FC,$00   ; 'C'
    .db $3C,$02,$36,$09,$66,$11,$66,$11,$EC,$03,$CC,$22,$F8,$06,$00,$FC
    .db $02,$00,$09,$00,$11,$00,$11,$00,$23,$00,$22,$00,$06,$00,$FC,$00   ; 'D'
    .db $3E,$01,$30,$0F,$60,$18,$78,$04,$C0,$3C,$C0,$20,$FC,$02,$00,$FE
    .db $01,$00,$0F,$00,$18,$00,$04,$00,$3C,$00,$20,$00,$02,$00,$FE,$00   ; 'E'
    .db $3E,$01,$30,$0F,$60,$18,$78,$04,$E0,$1C,$C0,$30,$C0,$20,$00,$E0
    .db $01,$00,$0F,$00,$18,$00,$04,$00,$1C,$00,$30,$00,$20,$00,$E0,$00   ; 'F'

draw_seed_row:                  ; main menu: "xxxxxxxx" after the label SEED, in two rows of the shifted tiles (see build_seed_tiles)
    lda #$0E0E                  ; x=14, y=14
    sta.l STR1
    ldx #STR1+2
    jsr build_seed_str
    lda #$0F0E                  ; x=14, y=15: lower halves
    sta.l STR1+11
    ldx #0
dsr_c:
    lda.l STR1+2,x
    and #$00FF
    sec
    sbc #$0030
    cmp #10
    bcc dsr_d
    sbc #7
dsr_d:
    asl a
    ora #$0080                  ; character code $80+2v: the game draws it as tile code - $40 = $40+2v
    sta.l SBV
    sep #$20
    lda.l SBV
    sta.l STR1+2,x
    inc a
    sta.l STR1+13,x
    rep #$20
    inx
    cpx #8
    bne dsr_c
    sep #$20
    lda #0
    sta.l STR1+10               ; terminator (byte: the next string starts right behind it)
    rep #$20
    lda #$0000
    sta.l STR1+21               ; terminator of the second string
    sta.l STR1+22               ; list end
    ldx #STR1
    jsl t_dstr
    rts

hook_menu_draw:                 ; main menu: draw the seed after the label "SEED"
    rep #$30
    jsr seed_init
    jsr build_seed_tiles
    jsr draw_seed_row
    stz $5A
    ldy $1FB0
    rtl

hook_lr:                        ; main menu, Left/Right pressed: entry 0 toggles 1/2 players (original), entry 2 rolls a new seed
    rep #$30
    lda $5A
    beq hlr_orig
    cmp #$0002
    beq hlr_roll
    jml $0F922F
hlr_orig:
    jml $0F9246
hlr_roll:
    jsr roll_seed
    jsr draw_seed_row
    jsl t_oam
    lda #$0084
    sta $0424
    jml $0F922F

hook_loc:                       ; splash screen: the seed under the header
    rep #$30
    lda #$040D                  ; x=13, y=4
    sta.l STR1
    lda #$0000
    sta.l STR1+2                ; attribute word
    ldx #STR1+4
    jsr build_seed_str
    lda #$0000
    sta.l STR1+12
    sta.l STR1+14
    ldx #STR1
    jsl t_list
    rtl

hook_laps8:                     ; 8-bit A = laps of this seed (called with M=8)
    sep #$20
    lda.l $7FF836
    rtl

hook_dist:                      ; 8-bit A = pieces per lap
    sep #$20
    lda.l $7FF832
    rtl

hook_blankmap:                  ; the decompressed minimap bitmaps (7E2000..) become blank
    rep #$30
    lda #$0000
    sta.l $7E2000
    ldx #$2000
    ldy #$2001
    lda #$3FFE
    mvn $7E,$7E
    sep #$20
    lda #$0F
    pha
    plb                         ; MVN leaves DBR = $7E; the menu expects $0F
    rep #$30
    rtl

hook_afterresults:              ; results screen finished: straight back to the main menu (title skipped once)
    rep #$30
    lda #$0001
    sta.l SKIPT
    jml $0F815A                 ; location_screen (title -> main menu -> splash), RTL returns to 00:8873 -> main_restart

hook_title:                     ; 0F:8C95 title_screen entry
    rep #$30
    lda.l $7FF806               ; the seed area is only valid after the first menu visit (WRAM is random at power-on)
    cmp #$A55A
    bne ht_orig
    lda.l SKIPT
    cmp #$0001
    bne ht_orig
    lda #$0000
    sta.l SKIPT
    jsl t_cleartext
    lda #$0708
    sta $66
    lda #$0107
    sta $1F84
    sta $1FA1
    sep #$20
    lda #$10
    sta $212C
    stz $212D
    lda #$81
    sta $4200
    lda #$03
    sta $2101
    rep #$20
    lda #$008F
    sta $42
    lda #$0001
    jsl t_vbl
    jml $0F8F5E                 ; TS=BG2, menu_graphics_load, main_menu
ht_orig:
    jsl t_cleartext
    jml $0F8C9A

seed_menu:                      ; entry 2 of the main menu, A pressed: hex keypad (src/keypad.asm)
    rep #$30
    jsl t_fadeout
    jsl t_font
    stz $5A
    lda #$0008
    jsl t_page
    jsl kp_run                  ; builds the screen, fades in, returns when END / START was pressed
    jsl t_fadeout
    jsl t_font
    jsr parse_seed
    jml $0F918B                 ; main_menu

parse_seed:                     ; $68..$6F typed characters, $5E = count: no characters = roll a new random seed
    lda $5E
    beq ps_roll
    lda #$0000
    sta.l V_LO
    sta.l V_HI
    ldy #0
ps_l:
    cpy $5E
    bcs ps_done
    lda $0068,y
    and #$00FF
    cmp #$0041
    bcc ps_d
    sbc #$0007
ps_d:
    and #$000F
    sta.l V_T
    ldx #4
ps_sh:
    lda.l V_LO
    asl a
    sta.l V_LO
    lda.l V_HI
    rol a
    sta.l V_HI
    dex
    bne ps_sh
    lda.l V_LO
    ora.l V_T
    sta.l V_LO
    iny
    bra ps_l
ps_done:
    lda.l V_LO
    sta.l SDL
    lda.l V_HI
    sta.l SDH
    rts
ps_roll:
    jmp roll_seed

.org $0F8C95
    jml hook_title              ; was: REP #$30 / JSR clear_text_buffer
    nop

.org $0F9242
    jml hook_lr                 ; was: LDA $5A / BNE $922F

; ---- title screen text (0F:8ED3 draws the list at $AFC6: entries = x column, y row, pixel offset x, y, text, 0; end = word 0) ---------------
; The new list has longer lines, so it lives in an unused stretch of bank $0F (never read in the menus or a race) and the LDX operand points to it.
; The copyright line of Gremlin Graphics is kept; the Nintendo licence and the Kemco lines are replaced.
.org $0F8ED4
    .dw $FB62
.org $0FFB62
    .db 3,26,2,0,$3F," 1991 GREMLIN GRAPHICS LTD",0
    .db 8,24,3,4,"POWERED BY CLAUDE",0           ; 17 chars, centred on pixel 135 like the original lines
    .db 11,20,2,2,"PRESS START",0
    .db 3,22,7,6,"RANDOMIZER BY PEDRO WALTER",0   ; 26 chars
    .dw 0
; The OAM buffer (128 sprites, text starts at sprite 56) cannot hold one sprite per character of the longer lines (81 with spaces, the original
; list had 70), so spaces no longer emit a sprite: the pending x of the next glyph just moves on by 8.  The loop at 0F:8EDC that
; adds $60 to the tile words counts the glyph sprites (71 now, was 70).
.org $0F9EFB                    ; was: LDA #$0100 / BNE loc_0F9F0C (space: carry is clear here, M = 16 bit)
    jmp $FBD0
    nop
    nop
.org $0F8EDD
    .dw $0046
.org $0FFBD0
    lda $0202,y
    clc
    adc #$0008
    sta $0202,y
    lda #0
    sep #$20
    jmp $9EEE                   ; next character
