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
    jmp $815A                   ; location_screen (title -> main menu -> splash), RTL returns to 00:8873 -> main_restart

.org $10F100
seed_init:                      ; first use after power-on: default seed, random mode
    lda.l $7FF806
    cmp #$A55A
    beq si_ok
    lda #$A55A
    sta.l $7FF806
    lda #$0000
    sta.l $7FF804
    lda #$1234
    sta.l $7FF800
    lda #$5678
    sta.l $7FF802
si_ok:
    rts

roll_seed:                      ; new random seed from the H/V counters (the player's reaction time) and the game's RNG words
    sep #$20
    lda.l $002137
    lda.l $00213C
    xba
    lda.l $00213D
    rep #$20
    eor.l $001FF4
    clc
    adc.l $001FFC
    sta.l $7FF800
    lda.l $001FF4
    asl a
    asl a
    eor.l $001FFC
    eor.l $001FF8
    clc
    adc.l $001FFA
    sta.l $7FF802
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
    lda.l $7FF804
    bne hp_fixed
    jsr roll_seed
hp_fixed:
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
