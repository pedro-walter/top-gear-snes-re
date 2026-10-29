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

; ---- 00:8785  "every car has stopped" test: a refuelled car counts as running again ------------------------
.org $008785
    jml hook_status             ; was: LDA $1EB4 / BEQ $87E1 (5 bytes)
    nop

; ---- 0F:8457  results shown: a single race has no world ranking (it would only show this race's points again) -----
.org $0F8457
    jsl hook_rank               ; was: JSR unpad_names / LDA #$0000 (6 bytes)
    nop
    nop

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
    jsr menu_init
    lda #0
    sta.l DONE
    sta.l PODIUM
    lda.l TRKS
    cmp #1
    beq hp_one
    jsr roll_seed               ; a series: every race has a fresh random seed (the SEED row is inactive)
hp_one:
    jsr clear_scores            ; the points are per race (1 TRACK) or per series
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
t_bfo:      jsr $86E7
    rtl
t_music:    jsr $8133                   ; play_music: A = song block (0 = title / menu music, 6 = the "completed Top Gear" tune)
    rtl

; ---- main menu entry 2: COUNTRY -> SEED -----------------------------------------------------------------
.org $0F918B
    jml mm_run                  ; the main menu is src/menu.asm (was: STZ $1F00 / LDA #1 / STA $1F02, same bytes first thing in mm_run)

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

draw_seed_row:                  ; main menu: "xxxxxxxx" after the label SEED, in two rows of the shifted tiles (see build_seed_tiles); A = tile row
    xba
    ora #$000E                  ; x=14, y=A
    sta.l STR1
    clc
    adc #$0100                  ; the lower halves one row below
    pha
    ldx #STR1+2
    jsr build_seed_str
    pla
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

hook_status:                    ; $1EB4 bit 0/1 = P1/P2 can still move. The game sets it again only when a car enters the pit empty
    rep #$30                    ; while no fade is running, so a car refuelled after the other one finished stayed "stopped" -> fade.
    lda.l $001F00               ; An unfinished car counts as running when it has fuel or is inside the pit sequence ($1E86/$1E88 < 0,
    bpl hs_p2_chk               ; e.g. waiting for the refuel to start, fuel still 0, fade countdown already running)
    lda.l $001E62
    bne hs_p1_set
    lda.l $001E86
    bpl hs_p2_chk
hs_p1_set:
    lda.l $001EB4
    ora #$0001
    sta.l $001EB4
hs_p2_chk:
    lda.l $001F02
    bpl hs_done
    lda.l $001E64
    bne hs_p2_set
    lda.l $001E88
    bpl hs_done
hs_p2_set:
    lda.l $001EB4
    ora #$0002
    sta.l $001EB4
hs_done:
    lda.l $001EB4
    bne hs_run
    jml $0087E1
hs_run:
    jml $00878A

hook_rank:                      ; unpad_names (copy: it clobbers A), then the ranking scroll, or straight to the fade out with 1 TRACK
    rep #$30
    ldx #$0007
    sep #$20
hr_l1:
    lda.l $001F86,x
    cmp #$3D
    bne hr_n1
    lda #$20
    sta.l $001F86,x
hr_n1:
    dex
    bpl hr_l1
    ldx #$0007
hr_l2:
    lda.l $001FA3,x
    cmp #$3D
    bne hr_n2
    lda #$20
    sta.l $001FA3,x
hr_n2:
    dex
    bpl hr_l2
    rep #$30
    lda.l TRKS
    cmp #1
    beq hr_skip
    lda #$0000
    rtl                         ; on to the scroll to the ranking (0F:845D)
hr_skip:
    pla                         ; drop the JSL return address (3 bytes)
    sep #$20
    pla
    rep #$20
    jml $0F8484                 ; fade_out_dma, then the rest of results_flow as after the ranking

hook_afterresults:              ; results + ranking are done (fade out done): back to the main menu, or on in a track series
    rep #$30
    lda.l TRKS
    cmp #1
    bne har_series
    lda #$0001
    sta.l SKIPT
    jml $0F815A                 ; location_screen (title -> main menu -> splash), RTL returns to 00:8873 -> main_restart
har_series:
    lda.l DONE
    inc a
    sta.l DONE
    lda.l TRKS
    beq har_next                ; infinite
    lda.l DONE
    cmp.l TRKS
    bcs podium_start
har_next:                       ; next race of the series: new seed, straight to the splash screen (like the original does after a passed race)
    jsr roll_seed
    jsr rando_env
    lda.l $7FF830
    sta.l $001F06
    sep #$20
    lda #$10
    sta $210E
    stz $210E
    rep #$20
    jsl t_font
    sep #$20
    stz $210E
    stz $210E
    rep #$20
    jml $0F818E                 ; location_screen after the title: splash of the next track, RTL -> main_restart

podium_start:                   ; series over: the scene screen of the original (driver on the stand + place label of every human), after the last ranking
    sep #$20
    lda #$10
    sta $210E                   ; BG1VOFS = $0010 as at 0F:8489 (the ranking scrolled the layer away)
    stz $210E
    rep #$20
    jsl t_font
    jsl t_bfo                   ; build_finish_order: $1FF8 / $1FFA = standing (1 = first) of car 0 / 1 from the sorted list $1F62
    lda $1FF8
    cmp #4
    bcc ps_win
    lda $1F04
    beq ps_sad
    lda $1FFA
    cmp #4
    bcc ps_win
ps_sad:
    ldx #1                      ; scene code 1 = the sad driver
    bra ps_go
ps_win:
    ldx #0                      ; scene code 0 = the celebrating driver, music 5
ps_go:
    lda #1
    sta.l PODIUM
    txa
    jml $0F84F5                 ; jmp_0F84F5 of results_flow: PHA PHA, graphics, driver, message, wait for a key

hook_podend:                    ; 0F:8669 end of the scene (stack: scene code): after the podium to the title screen, else as the original
    pla
    tax
    lda.l PODIUM
    bne pe_menu
    txa
    bne pe_flag
    jml $0F818E
pe_flag:
    jml $0F866F
pe_menu:
    lda #0
    sta.l PODIUM
    jsl t_music                 ; A = 0: stops the podium tune and uploads + starts the title music again (as the original does before its title return)
    jml $0F815A                 ; back to the title screen (KEMCO intro, PRESS START), like after power-on

hook_msg0:                      ; 0F:8584 scene code 0: the message
    lda.l PODIUM
    bne hm0_p
    ldx #$B1C7
    bra hm0_d
hm0_p:
    ldx #addr(msg_win)
    jsl t_dstr
    jsr pod_bang
    lda #6                      ; the tune of the original "completed Top Gear" scene (not the qualified one, 5)
    jsl t_music
    jml $0F859D
hm0_d:
    jsl t_dstr
    jml $0F858A

hook_msg1:                      ; 0F:8592 scene code 1
    lda.l PODIUM
    bne hm1_p
    ldx #$B23B
    bra hm1_d
hm1_p:
    ldx #addr(msg_lose)
    jsl t_dstr
    jsr pod_bang
    lda #6                      ; same tune for the sad driver (the original plays none there)
    jsl t_music
    jml $0F859D
hm1_d:
    jsl t_dstr
    jml $0F859D

hook_pw:                        ; 0F:85F2 scene screen: the password block is only for the original country flow
    lda.l PODIUM
    bne hpw_skip
    lda $1F06
    and #$001C
    beq hpw_skip
    jml $0F85FA
hpw_skip:
    jml $0F863B

clear_scores:                   ; points of the 20 cars: the original bytes ($1F4E) and the 16 bit scores
    ldx #$0012
cs_l:
    stz $1F4E,x
    dex
    dex
    bpl cs_l
    sep #$20
    ldx #19
    lda #0
cs_t:
    sta.l TOTLO,x
    sta.l TOTHI,x
    dex
    bpl cs_t
    rep #$20
    rts

hook_addpts:                    ; 0F:8889 (M = 8 bit, Y = car id, X = position 0..9): score of the car += points of the position
    .a8
    lda.l $0E8024,x
    sta.l MMT
    phx
    tyx
    lda.l TOTLO,x
    clc
    adc.l MMT
    sta.l TOTLO,x
    lda.l TOTHI,x
    adc #0
    bcc ha_s
    lda #$FF
    sta.l TOTLO,x
ha_s:
    sta.l TOTHI,x
    plx
    rtl
    .a16

hook_cmp:                       ; 0F:896F inside the ranking sort (M = X = 8 bit): C = score of car Y >= score of car X (BCC follows)
    .a8
    .i8
    phb
    lda #$7F
    pha
    plb
    lda addr(TOTHI),y
    cmp addr(TOTHI),x
    bne hc_d
    lda addr(TOTLO),y
    cmp addr(TOTLO),x
hc_d:
    plb                         ; PLB leaves the carry alone
    rtl
    .a16
    .i16

hpc_tab:
    .dw 10000,1000,100,10

hook_ptscol:                    ; 0F:8B4E draw_points_column: the scores (0..65535) LEFT aligned from column 17, one row per rank
    rep #$30
    ldy #0
hpc_l:
    phy
    lda $1F62,y
    and #$00FF
    tax
    sep #$20
    lda.l TOTHI,x
    xba
    lda.l TOTLO,x
    rep #$20
    sta.l MMT                   ; remaining value
    ldx #0                      ; offset in hpc_tab
    ldy #0                      ; digit
hpc_n:
    lda #0
    sta.l MMT+2                 ; this digit
hpc_c:
    lda.l MMT
    cmp.l hpc_tab,x
    bcc hpc_w
    sbc.l hpc_tab,x
    sta.l MMT
    lda.l MMT+2
    inc a
    sta.l MMT+2
    bra hpc_c
hpc_w:
    lda.l MMT+2
    sep #$20
    clc
    adc #$30
    sta $1FC0,y
    rep #$20
    iny
    inx
    inx
    cpx #8
    bne hpc_n
    lda.l MMT                   ; ones
    sep #$20
    clc
    adc #$30
    sta $1FC0,y
    ldx #0                      ; skip leading zeros (the ones digit stays)
hpc_z:
    lda $1FC0,x
    cmp #$30
    bne hpc_zd
    cpx #4
    beq hpc_zd
    inx
    bra hpc_z
hpc_zd:
    ldy #0
hpc_m:
    cpx #5
    beq hpc_p
    lda $1FC0,x
    sta $1FB4,y
    inx
    iny
    bra hpc_m
hpc_p:
    cpy #5
    beq hpc_e
    lda #$20                    ; blanks behind the number
    sta $1FB4,y
    iny
    bra hpc_p
hpc_e:
    lda #0
    sta $1FB4,y
    sta $1FB5,y
    sta $1FB6,y
    rep #$20
    ply
    phy
    tya
    xba
    clc
    adc #$2611
    sta $1FB2
    ldx #$1FB2
    jsl t_dstr
    ply
    iny
    cpy #20
    beq hpc_x
    jmp hpc_l
hpc_x:
    jml $0F9294                 ; the RTS of main_menu: back to draw_points_table's caller

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

; ---- title screen text (0F:8ED3 draws the list at $AFC6: entries = x column, y row, pixel offset x, y, text, 0; end = word 0) ---------------
; The new list has longer lines, so it lives in an unused stretch of bank $0F (never read in the menus or a race) and the LDX operand points to it.
; The Nintendo licence, Kemco and Gremlin lines are replaced; the last line is `VERSION <VERSION in tools/build_rando.py>`.
.org $0F8ED4
    .dw $FB62
.org $0FFB62
    @TITLE_LIST@                ; generated by tools/build_rando.py (title_lines): lines + the version, list end
; The OAM buffer (128 sprites, text starts at sprite 56) cannot hold one sprite per character of the longer lines (81 with spaces, the original
; list had 70), so spaces no longer emit a sprite: the pending x of the next glyph just moves on by 8.  The loop at 0F:8EDC that
; adds $60 to the tile words counts the glyph sprites (computed at build time, was 70).
.org $0F9EFB                    ; was: LDA #$0100 / BNE loc_0F9F0C (space: carry is clear here, M = 16 bit)
    jmp $FBD0
    nop
    nop
.org $0F8EDD
    .dw @TITLE_GLYPHS@-1        ; glyph count - 1, computed by tools/build_rando.py
.org $0FFBD0
    lda $0202,y
    clc
    adc #$0008
    sta $0202,y
    lda #0
    sep #$20
    jmp $9EEE                   ; next character

; ---- scoring: 16 bit scores per car, kept over the races of a series (see src/menu.asm) ---------------------------------
.org $0F8889
    jsl hook_addpts             ; was: CLC / LDA $1F4E,Y / ADC $0E8024,X / STA $1F4E,Y (11 bytes)
    nop
    nop
    nop
    nop
    nop
    nop
    nop
.org $0F896F
    jsl hook_cmp                ; was: LDA $1F4E,Y / CMP $1F4E,X (6 bytes; the BCC at 0F:8975 stays)
    nop
    nop
.org $0F8B4E
    jml hook_ptscol             ; draw_points_column
.org $0F8584
    jml hook_msg0               ; was: LDX #$B1C7 / (JSR draw_string)
.org $0F8592
    jml hook_msg1               ; was: LDX #$B23B / BRA $859A
    nop
.org $0F8669
    jml hook_podend             ; was: PLA / BNE $866F / JMP $818E
    nop
    nop
.org $0F85F2
    jml hook_pw                 ; was: LDA $1F06 / AND #$001C / BEQ $863B (8 bytes)
    nop
    nop
    nop
    nop
.org $0FA733                    ; title of the difficulty page (was "SKILL LEVEL", same length): the main menu row is called DIFFICULTY
    .db $05,$04,"DIFFICULTY ",0

; ---- 05:E55C / E577 / E73B / E756  car-to-car collision: the car is pushed back to "other car's position - 8" ----
; The other car's position can already belong to the next lap (it crossed the line, the human has not yet) or to the
; previous one.  The plain subtraction then gave a position just before the start (>= $FC00 = "previous lap"): the
; lap check took a lap off and the next crossing only gave it back -> the lap did not count.  The other way round
; (human already across, other car not) the lap was counted twice.  Fix: compute the new position in the human's own lap.
.org $05E55C                    ; human 1 hits the computer car (player 2)
    jsl hook_hit1               ; was: SEC / SBC #$0008 / STA $1ED7 (7 bytes; A = other position)
    nop
    nop
    nop
.org $05E577                    ; human 1 hits a bot ($1B = bot position)
    jsl hook_hit1
    nop
    nop
    nop
.org $05E73B                    ; player 2 / computer car hits human 1
    jsl hook_hit2               ; was: SEC / SBC #$0008 / STA $1EDA
    nop
    nop
    nop
.org $05E756                    ; player 2 / computer car hits a bot
    jsl hook_hit2
    nop
    nop
    nop

.org $138000
.a16
.i16
hook_hit1:                      ; A = position of the other car, X = its car-list slot (M = X = 16 bit)
    ldy $0204
    jsr hit_pos
    sta $1ED7
    rtl
hook_hit2:
    ldy $0206
    jsr hit_pos
    sta $1EDA
    rtl
hit_pos:                        ; Y = slot of the car that was hit -> A = other position - 8, in that car's own lap
    sec
    sbc #$0008
    pha
    lda $0219,y
    cmp #$FC00
    bcs hitp_orig                 ; still behind the line of lap 1 (positions count backwards from the length)
    sep #$20
    lda $021B,x                 ; lap byte of the other car minus ours
    sec
    sbc $021B,y
    rep #$20
    and #$00FF
    beq hitp_same
    cmp #$0001
    beq hitp_up
    cmp #$00FF
    bne hitp_orig
    lda $0219,y                 ; the other car is one lap behind: only if we are just across the line and it is not
    cmp #$0400                  ; (both before the line = a backmarker at the same spot: keep the plain position)
    bcs hitp_orig
    pla
    sec
    sbc $0200
    cmp #$FBF8                  ; and it must be right before the line
    bcs hitp_clamp
    clc
    adc $0200
    rts
hitp_up:                          ; the other car crossed the line already, we are about to (else it lapped us: plain position)
    lda $0200                   ; (our position may already be past the length: the wrap comes later, at 05:E789)
    sec
    sbc #$0400
    cmp $0219,y
    bcs hitp_same               ; not within the last $0400: plain position, but never behind the line
    pla
    cmp #$0400                  ; and it must be right after the line
    bcc hitp_add
    cmp #$FC00
    bcc hitp_ret
hitp_add:
    clc
    adc $0200
    bra hitp_clamp
hitp_same:
    pla
hitp_clamp:
    cmp #$FC00                  ; below the start line of our lap: stop on the line
    bcs hitp_zero
    cmp $0200
    bcc hitp_ret
    lda $0200
    dec a
    rts
hitp_zero:
    lda #$0000
hitp_ret:
    rts
hitp_orig:
    pla
    rts
