; ============================================================================================================
; Main menu (replaces main_menu 0F:918B) and the track series.
;
;   1 PLAYER / DIFFICULTY / <n> TRACKS / SEED / SPEED KPH / PLAY GAME
;
; The original menu has five fixed rows 4 tile rows apart; this one has six rows 3 tile rows apart (rows 6, 9 .. 21 inside the frame of
; page 0), drawn by this code.  Left/Right: players, number of tracks (infinity .. 99), seed roll, speed unit.  The SEED row is only
; active with "1 TRACK"; otherwise label, digits and selector bar are grey.
;
; Track series (TRKS != 1): every race gets a fresh random seed, the results of all races add up in a 16 bit score per car (TOTLO/TOTHI,
; shown by the world ranking), and after the last race the podium scene (driver + place of every human) is shown.  There is no
; qualification: nothing in the series ever ends in "game over".  See hook_afterresults / podium_start in hooks.asm.
; Runs with DBR = $0F, M = X = 16 bit (menu code of bank $0F); WRAM beyond $1FFF is reached with long addressing.
; ============================================================================================================
.a16
.i16
TRKS    = $7FFA00               ; tracks of the series: 0 = infinite, 1 = a single race (default), 2..99
DONE    = $7FFA02               ; races of the series finished so far
PODIUM  = $7FFA04               ; 1 while the end-of-series scene is on screen
MCUR    = $7FFA06               ; menu row to come back to after a submenu
CUR     = $7FFA08               ; menu row of the selector
SELG    = $7FFA0A               ; 1 while the selector (sprite palette 7) is grey
MMT     = $7FFA0C               ; scratch
MAGIC2  = $7FFA10               ; $5AA5 once the menu state below is initialised (WRAM is random at power-on; test scripts poke the seed magic only)
TOTLO   = $7FFA20                ; low bytes of the scores of the 20 cars (bank $7F; abs addressing with DBR = $7F uses addr(TOTLO))
TOTHI   = $7FFA40                ; high bytes
MK_FIELD = (((6 + 6) * 32) + 5) * 2   ; buffer offset of the number field of the X TRACKS row (tile row ROW0 + 6, column 5)
ROW0    = 6                     ; first menu row (tile row of the label's top half); rows are 3 tiles apart
MM_ROWS = 6

.org $10A000

; ---- selector colours / palette ---------------------------------------------------------------------------------------------
mm_grey_text:                   ; the gold font's palette (index 8..15 = gradient) as a grey one; replaces BG palette 5 ($050C, unused on the menu page; palette 1 is the photo) on the menu
    .dw $0000,$5EF7,$0000,$0000,$14A5,$0421,$0421,$0C63,$5EF7,$5294,$4A52,$4631,$4210,$39CE,$35AD,$318C
mm_grey_bar:                    ; the blue selector bar (sprite palette 7, $064C) in grey
    .dw $0000,$6B5A,$318C,$0000,$294A,$0842,$0842,$0C63,$6B5A,$5EF7,$5294,$4631,$35AD,$294A,$2529,$2108

mm_t_1p:    .db "1 PLAYER ",0
mm_t_2p:    .db "2 PLAYERS",0
mm_t_diff:  .db "DIFFICULTY",0
mm_t_seed:  .db "SEED   ",0
mm_t_kph:   .db "SPEED KPH",0
mm_t_mph:   .db "SPEED MPH",0
mm_t_play:  .db "PLAY GAME",0
mm_t_trks:  .db "TRACKS",0
mm_t_trk1:  .db "TRACK ",0

mm_pal_text:                    ; grey text palette -> palette shadow (BG palette 5)
    ldx #30
mpt_l:
    lda.l mm_grey_text,x
    sta $050C,x
    dex
    dex
    bpl mpt_l
    rts

mm_push_pal:                    ; the NMI copies the shadow to CGRAM when $90 = $4C (and then sets $0424 = 2); one frame later all is back to normal
    lda #$004C
    sta $90
    lda #1
    jsl t_vbl
    rts

mm_selpal:                      ; selector colour for the row in CUR: grey on the SEED row while it is inactive
    lda.l CUR
    cmp #3
    bne msp_n
    lda.l TRKS
    cmp #1
    beq msp_n
    lda #1
    bra msp_s
msp_n:
    lda #0
msp_s:
    cmp.l SELG
    beq msp_ret
    sta.l SELG
    ldx #30
    cmp #0
    beq msp_o
msp_g:
    lda.l mm_grey_bar,x
    sta $064C,x
    dex
    dex
    bpl msp_g
    bra msp_d
msp_o:
    lda.l $0EFD66,x             ; the original sprite palette 7 (also what restore_palette copied there)
    sta $064C,x
    dex
    dex
    bpl msp_o
msp_d:
    jsr mm_push_pal
msp_ret:
    rts

; ---- text ---------------------------------------------------------------------------------------------------------------------
mm_text:                        ; A = (row << 8) | column, X = zero terminated text in bank $10: big font into the text buffer
    sta $1FB2
    ldy #0
    sep #$20
mt_c:
    lda.l $100000,x
    sta $1FB4,y
    beq mt_e
    inx
    iny
    bra mt_c
mt_e:
    lda #0
    sta $1FB5,y                 ; two zeros after the terminator = end of the list
    sta $1FB6,y
    rep #$20
    ldx #$1FB2
    jsl t_dsb
    rts

mm_rowy:                        ; A = menu row 0..5 -> A = tile row of its label
    sta.l MMT
    asl a
    clc
    adc.l MMT
    adc #ROW0
    rts

mm_tracks:                      ; row 2: "<n>  TRACKS" / "<infinity> TRACKS": a two-glyph number field (digits left aligned), a blank, then the word
    lda.l TRKS
    bne mk_n
    ldx #MK_FIELD               ; the infinity sign fills the field: left half, right half (kp_gfx slots 16 / 17, tiles 320 / 322)
    lda #320
    jsr mm_quad
    ldx #MK_FIELD + 4
    lda #322
    jsr mm_quad
    bra mk_txt
mk_n:
    ldx #0
mk_t:
    cmp #10
    bcc mk_d
    sbc #10
    inx
    bra mk_t
mk_d:
    sta.l MMT                   ; ones; X = tens
    txa
    beq mk_one
    ldx #MK_FIELD
    jsr mm_dig
    lda.l MMT
    ldx #MK_FIELD + 4
    jsr mm_dig
    bra mk_txt
mk_one:
    lda.l MMT
    ldx #MK_FIELD
    jsr mm_dig
    lda #$FFFF                  ; second cell empty
    ldx #MK_FIELD + 4
    jsr mm_dig
mk_txt:
    ldx #addr(mm_t_trks)
    lda.l TRKS
    cmp #1
    bne mk_w
    ldx #addr(mm_t_trk1)
mk_w:
    lda #((ROW0 + 6) << 8) | 11
    jmp mm_text

mm_dig:                         ; A = digit 0..9 (or $FFFF = blank), X = buffer offset: the digit's 16x16 glyph (kp_gfx, tiles 256..) as 2x2 tiles
    cmp #$FFFF
    bne md_d
    lda #128                    ; blank glyph of the game's font
    bra mm_quad
md_d:
    phx
    asl a
    tax
    lda.l kp_keys,x             ; tile of hex value A
    plx
mm_quad:                        ; A = top-left tile, X = offset into the tilemap buffer ($0C6C+X): sprite layout, lower half 16 tiles on
    sta $0C6C,x
    inc a
    sta $0C6E,x
    clc
    adc #15
    sta $0CAC,x
    inc a
    sta $0CAE,x
    rts

mm_grey_row:                    ; A = tile row: palette 5 (grey) for both tile rows from column 5 to 23
    xba
    lsr a
    lsr a                       ; row * 64
    clc
    adc #10
    tax
    ldy #19
mg_l:
    lda $0C6C,x
    ora #$1400
    sta $0C6C,x
    lda $0CAC,x
    ora #$1400
    sta $0CAC,x
    inx
    inx
    dey
    bne mg_l
    rts

mm_row:                         ; A = menu row: (re)draws its label
    cmp #1
    beq mr_1
    cmp #2
    beq mr_2
    cmp #3
    beq mr_3
    cmp #4
    beq mr_4
    cmp #5
    beq mr_5
    ldx #addr(mm_t_1p)          ; 0: players
    lda $1F04
    beq mr_0a
    ldx #addr(mm_t_2p)
mr_0a:
    lda #(ROW0 << 8) | 5
    jmp mm_text
mr_1:
    ldx #addr(mm_t_diff)
    lda #((ROW0 + 3) << 8) | 5
    jmp mm_text
mr_2:
    jmp mm_tracks
mr_3:                           ; seed: label, 8 digits (small font), grey unless "1 TRACK"
    ldx #addr(mm_t_seed)
    lda #((ROW0 + 9) << 8) | 5
    jsr mm_text
    lda #ROW0 + 9
    jsr draw_seed_row
    lda.l TRKS
    cmp #1
    beq mr_3r
    lda #ROW0 + 9
    jsr mm_grey_row
mr_3r:
    rts
mr_4:
    ldx #addr(mm_t_mph)
    lda $1FB0
    beq mr_4a
    ldx #addr(mm_t_kph)
mr_4a:
    lda #((ROW0 + 12) << 8) | 5
    jmp mm_text
mr_5:
    ldx #addr(mm_t_play)
    lda #((ROW0 + 15) << 8) | 5
    jmp mm_text

mm_len:                         ; A = menu row -> A = length of its selector bar (text width in 16 pixel steps + 1)
    cmp #1
    beq ml_1
    cmp #2
    beq ml_2
    cmp #3
    beq ml_3
    cmp #4
    bcs ml_4
    lda $1F04
    clc
    adc #9
    rts
ml_1:
    lda #11
    rts
ml_2:                           ; field (2) + blank + TRACKS (6), one less letter for "1 TRACK"; +1
    lda.l TRKS
    cmp #1
    beq ml_one
    lda #10
    rts
ml_one:
    lda #9
    rts
ml_3:
    lda #9
    rts
ml_4:
    lda #10
    rts

mm_bar:                         ; selector bar of the row in CUR
    lda.l CUR
    jsr mm_rowy
    xba
    ora #3
    sta $48
    lda.l CUR
    jsr mm_len
    sta $4A
    ldx #4
    jsl t_bar
    rts

mm_flush:                       ; send OAM + tile map, then wait for the buttons to be released (like the original loop at 0F:922F)
    jsl t_oam
    lda #$0084
    sta $0424
mm_rel:
    lda $0A
    bne mm_rel
    lda #$04B0
    sta $1FF6                   ; attract countdown restarts
    bra mm_loop

menu_init:                      ; first use after power-on: one race, no series running, scores cleared
    lda.l MAGIC2
    cmp #$5AA5
    beq mi_ok
    lda #$5AA5
    sta.l MAGIC2
    lda #0
    sta.l DONE
    sta.l PODIUM
    sta.l MCUR
    lda #1
    sta.l TRKS
    jsr clear_scores
mi_ok:
    rts

; ---- entry (patched over main_menu, 0F:918B) -------------------------------------------------------------------------------
mm_run:
    rep #$30
    stz $1F00                   ; previous places: the human starts the grid in the first row again
    lda #1
    sta $1F02
    jsr seed_init
    jsr menu_init
    lda #0
    jsl t_page                  ; page 0: frame and title (its label list was redirected to mm_title), palette
    jsr build_seed_tiles
    jsl kp_build_glyphs         ; the big digits and the infinity halves (VRAM tiles 256..351)
    jsr mm_pal_text
    lda.l MCUR
    sta.l CUR
    lda #0
    sta.l SELG
    ldy #0
mm_i:
    tya
    phy
    jsr mm_row
    ply
    iny
    cpy #MM_ROWS
    bcc mm_i
    jsr mm_bar
    jsr mm_selpal
    jsr mm_push_pal
    jsl t_oam
    lda #$0084
    sta $0424
    jsl t_fadein
mm_loop:
    lda #1
    jsl t_vbl
    lda $0A
    and #$FFF0
    beq mm_loop
    and #$0C00
    beq mm_nud
    and #$0800
    beq mm_down
    lda.l CUR
    dec a
    bpl mm_set
    lda #MM_ROWS - 1
    bra mm_set
mm_down:
    lda.l CUR
    inc a
    cmp #MM_ROWS
    bcc mm_set
    lda #0
mm_set:
    sta.l CUR
    jsr mm_bar
    jsr mm_selpal
    jmp mm_flush
mm_nud:
    lda $0A
    and #$0300
    bne mm_lr
    jmp mm_enter

mm_lr:                          ; Left / Right
    lda.l CUR
    beq mlr_pl
    cmp #2
    beq mlr_tr
    cmp #3
    beq mlr_seed
    cmp #4
    beq mlr_sp
    jmp mm_rel
mlr_pl:
    lda $1F04
    eor #1
    sta $1F04
    lda #0
    jsr mm_row
    jsr mm_bar
    jmp mm_flush
mlr_sp:
    jsr mm_toggle_speed
    jmp mm_flush
mlr_seed:
    lda.l TRKS
    cmp #1
    bne mlr_ign
    jsr roll_seed
    lda #3
    jsr mm_row
    jsr mm_bar
    jmp mm_flush
mlr_ign:
    jmp mm_rel
mlr_tr:                         ; ... 98 99 <infinity> 1 2 ... (left from "1 TRACK" = infinity)
    lda $0A
    and #$0100
    bne mlr_up
    lda.l TRKS
    dec a
    bpl mlr_st
    lda #99
    bra mlr_st
mlr_up:
    lda.l TRKS
    inc a
    cmp #100
    bcc mlr_st
    lda #0
mlr_st:
    sta.l TRKS
    lda #2
    jsr mm_row
    lda #3
    jsr mm_row                  ; the seed row greys / un-greys
    jsr mm_bar
    jmp mm_flush

mm_toggle_speed:
    lda $1FB0
    eor #$FFFF
    sta $1FB0
    lda #4
    jmp mm_row

mm_enter:                       ; A / Start / ...
    lda.l CUR
    cmp #3
    bne mme_n3
    lda.l TRKS
    cmp #1
    beq mme_leave
    jmp mm_rel                  ; SEED is inactive in a series
mme_n3:
    cmp #4
    bne mme_leave
    jsr mm_toggle_speed
    jmp mm_flush
mme_leave:
    lda.l CUR
    sta.l MCUR
    jsl t_fadeout
    jsl t_font
    stz $1FF6
    lda.l CUR
    beq mme_pl
    cmp #1
    beq mme_df
    cmp #3
    beq mme_sd
    lda #0
    sta.l MCUR                  ; PLAY GAME: next time from the top
    jml hook_play
mme_pl:
    jml $0F929B                 ; player_setup_menu (names, controls, cars); returns to main_menu
mme_df:
    jml $0F9652                 ; skill_menu (AMATEUR / PROFESSIONAL / CHAMPIONSHIP)
mme_sd:
    jml seed_menu

pod_bang:                       ; the "!" of the podium message: tile $60 of the scene's font area (VRAM word $1600, free there), written in forced blank
    sep #$20
    stz $4200
    lda #$80
    sta $2100
    sta $2115
    rep #$20
    lda #$1600
    sta.l $002116
    ldx #0
pb_l:
    lda.l pb_gfx,x
    sta.l $002118
    inx
    inx
    cpx #32
    bcc pb_l
    sep #$20
    lda #$81
    sta $4200
    rep #$20
    lda #$0060
    sta $0C6C+(24*32+26)*2      ; column 26 of tile row 24 = right behind the text
    rts
pb_gfx:
    .db $3C,$02,$38,$04,$18,$04,$30,$08,$30,$08,$00,$00,$38,$04,$00,$18,$02,$00,$04,$00,$04,$00,$08,$00,$08,$00,$00,$00,$04,$00,$18,$00

.org $0FFF17                    ; free tail of bank $0F: the title of page 0 and the podium messages (draw_string needs bank $0F addresses)
mm_title:
    .db $09,$02,"OPTIONS",0,0,0
msg_win:                        ; the same text for the celebrating and the sad driver; the "!" is a drawn tile (the font has none), see pod_bang
msg_lose:
    .db $05,$18,"THANK YOU FOR PLAYING",0,0,0

.org $0DC738                    ; page table b (strings of page 0 and 1): the main menu labels are drawn by mm_row, only the title stays
    .dw mm_title & $FFFF, mm_title & $FFFF
