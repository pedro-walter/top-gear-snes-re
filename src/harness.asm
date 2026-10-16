; Test harness: reset vector -> loop { generate(seed in 7F:0800); h_done }.  A Lua script hooks h_done.
.a16
.i16
.org $10F800
h_reset:
    sei
    clc
    xce
    rep #$38
    ldx #$1FFF
    txs
    lda #$0000
    tcd
    sep #$20
    lda #$80
    sta $2100
    stz $4200
    stz $420B
    stz $420C
    rep #$30
    lda #$0001
    sta $1F10
h_loop:
    jsr rando_generate
h_done:
    nop
    bra h_loop
.org $008000
    jml h_reset                 ; game reset entry (was CLD / SEI / ...)
