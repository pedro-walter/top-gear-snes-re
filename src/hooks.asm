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
