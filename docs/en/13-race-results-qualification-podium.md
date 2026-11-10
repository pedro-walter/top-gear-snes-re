# Post-race flow: results, championship points, qualification, game over, podium scene

Everything here was read from the disassembly (`results_flow` 0F:83D7 and friends) and then **reproduced in headless Mesen** by forging a race end
(`scripts/race_end_force.lua`, see "How to reproduce"). The exact paths and messages below were all seen on screen.
Names: `$1F4E` etc. are in `disasm/annot/ram.txt`, routines in `disasm/annot/symbols.txt`.

## 1. Where the race hands over
* Race loop (00:877D): `$1EB0` (finish_count) >= 10 -> `race_exit` 00:8834 -> `JSL menu_entry` (0F:806D) with **A=1** -> `results_flow`.
  (A=0 is the boot/new-game path = `location_screen`.) Afterwards 00:8875 `JMP main_restart` starts the next race.
* `$1F12[0..9]` = car ids in finish order (written by `cars_update` 00:A1F9 for bots and 05:E7E2 for the human; `race_end_simulation`
  fills the rest), `$1F26 + 2*id` = finish time in frames, `$1F00` / `$1F02` = 0-based race place of player 1 / 2 (`$1EB0` at the moment they finished).
  Car id 0 = player 1, id 1 = player 2 / the COMPUTER car, ids 2..19 = the 18 named bots (names at 0D:C47B + (id-2)*8).
* `$1F00..$1FFF` is **not** cleared by `main_restart` (it clears `$0000-$1EFF` only), so this block is the persistent "save state" of a
  session: track `$1F06`, skill `$1F10`, unlock `$1F0A`, points `$1F4E`, names, lap records `$1FB2`, ...

## 2. Screens, in order (all inside `results_flow`, 0F:83D7)
1. **RESULTS** (`draw_race_result_table` 0F:882D): 10 rows, place, name, time (first row absolute, others `+gap`), points for this race. Wait for a key.
2. **WORLD RANKING** (`draw_points_table` 0F:894F): all 20 cars sorted by championship points, scrolled up and down. Wait for a key.
3. Qualification test (below). Depending on the outcome:
   * mid-country pass -> straight to the main menu (`loc_0F818E`) with the next track selected, **no message**;
   * everything else -> the **scene screen** (section 5) with a message, then either the main menu or the title/KEMCO screen.

## 3. Championship points
* Table at **0E:8024**, indexed by finish position 0..9: `20 15 12 10 8 6 4 3 2 1` (then zeros). Only the 10 entries of `$1F12` score.
* `$1F4E + car id` (1 byte per car, 20 bytes). They are **added as a side effect of drawing** the RESULTS table (0F:887F..8891:
  `$1F4E[id] += 0E:8024[position]`), i.e. only when the results screen runs.
* Kept between races because nothing clears them except:
  * boot (00:80B2, runs only on reset),
  * `advance_track` at the **start of a new country** (0F:8750, i.e. after every 4th race, *before* the country test, using the already built sorted list),
  * both failure paths (0F:84CB / 0F:84E1).
  The main menu (COUNTRY / SKILL / 1-2 PLAYERS) never touches them; so switching country mid-way keeps the points.
* `draw_points_table` builds `$1F62[0..19]` = car ids sorted by points, **best first** (a bubble sort on `$1F4E[id]`; ties keep list order),
  and draws names (0D:C47B table; id 0 / 1 use the player names, or "COMPUTER") plus the points column (`draw_points_column`, 0F:8B4E, capped 2 digits by `byte_to_ascii`).
  So `$1F62` is the championship standing and `$1F62[0]` is the leader.

## 4. Qualification (this is the "game over")
A country = 4 consecutive tracks (`$1F06 & 3` = 0..3, country = `$1F06 >> 2`, 8 countries, 32 tracks). Let `N` = number of humans (`$1F04 + 1`; 1 in 1P, 2 in 2P); car ids < N are the humans.

| test | code | rule | fail result |
|---|---|---|---|
| **per race** `qualify_check_1p` 0F:871A | called at 0F:84A4 | a human id must be among the first **5** entries of `$1F12` (finished 1st..5th in the race) | message A=1, points wiped |
| **per country** `advance_track` 0F:8733 | only after the 4th race (`$1F06 & 3 == 0` after the INC) | a human id must be among `$1F62[0..2]` (**top 3** of the championship standing, tie-order as sorted) | message A=2, points wiped |

Verified boundaries in the emulator: 5th place in a race passes, 6th fails; 3rd in the standings qualifies, 4th does not (tests: `PLACE=4`/`5`, `PTS=` forging).
In 2P either human passing is enough. Difficulty does not change the thresholds (it only changes which password/continue text is shown).

Flow after the tests (`results_flow` 0F:84A4-84F5; the value that ends up on the stack = message code `A`):

| outcome | A | what happens |
|---|---|---|
| race test failed (0F:84CB) | **1** | points `$1F4E` zeroed, `$1F00=0`, `$1F02=1` (grid reset: human starts at the back); **`advance_track` is skipped**, `$1F06` unchanged. |
| race OK, mid-country | 1 (from `advance_track`, carry clear) | `$1F06++`, `JMP 0F:818E` = main menu with the next track. No message screen. |
| country-end OK, not the last country | **0** | `$1F06` is already the first track of the next country; shows the happy scene + password, then `JMP 0F:818E` (main menu). |
| country-end failed (0F:84E1) | **2** | points zeroed, grid reset like A=1, `$1F06` is **already advanced to the next country** (see quirk). |
| country-end OK on track 31 (`$1F06` wraps to 0) | **3** | "completed Top Gear" scene (0F:84C0 sets A=3 when `$1F06 == 0`). |

The A=1 value that `advance_track` returns for "next race in this country" is also what the failed-race path pushes; the two are told apart by the `BCS` right after `qualify_check_1p`.
The **grid reset** (`$1F00=0, $1F02=1` = previous finishing places) is what makes the human start at the back/front of the next grid (see docs/03).

### What a failure does to the program flow
Messages with A != 0 end at 0F:866F: `$1FF6 (attract_flag) = A` (1/2/3), music 0, then
```
$1F08 = $1F06 & 0x1C ; $1F0A[skill] = max($1F0A[skill], $1F08 >> 2) ; JMP results_flow
```
and the top of `results_flow` (0F:83DD) sees `$1FF6 != 0`: `$1F06 = $1F08` and `JMP location_screen` (0F:815A) -> `title_screen` (0F:8C95) with the full intro:
**KEMCO "presents" logo -> TOP GEAR logo animation -> PRESS START** (about 860 frames until the title waits for a key), the same sequence as at power-on.
The title screen overwrites `$1FF6` with the 0x04B0 attract countdown, so the flag only serves to make `results_flow` take this branch. A key press then goes to the main menu
(options: 1 PLAYER / SKILL LEVEL / COUNTRY / SPEED / PLAY GAME, `main_menu` 0F:918B); a 0x4B0-frame idle countdown starts the attract demo race instead.
Only A=0 (country passed) skips the title and goes straight to the menu. Names, lap records, skill, units, controls survive; points and grid positions do not.

### Quirks found (so nobody trips over them)
* **Failing the country-end test does not really block the next country.** `advance_track` has already incremented `$1F06` to the next country base, so
  `$1F08` / `$1F0A[skill]` get the next country: after "SORRY YOU FAILED TO QUALIFY FOR THE NEXT COUNTRY" the main menu is on country N+1 and COUNTRY lists it as unlocked
  (observed: `$1F06=4`, `$1F0A=1` after failing at track 3). Only the points are lost. Failing a single race (A=1) does keep you on the same country (`$1F06` unchanged -> restarts at the
  first track of that country, since `$1F06 = $1F08` = country base).
* The fail message A=2 **also prints the next country's password** (the password code at 0F:85F2 only tests `$1F06 & 0x1C != 0`).
* The place printed next to the player name is the **race place** for the A=1 fail (`$1F00+1`, `build_finish_order` is skipped) but the **championship standing**
  for every other path (`build_finish_order` 0F:86E7 reads `$1F62`, so "PLAYER 1  9TH" after a failed country means 9th in the standings).
* `advance_track`'s loop at 0F:875E compares adjacent ids that are always different, so it is a constant `Y=2` ("top 3"), not a tie test.
* Passwords for a country are only displayed (never required while playing): `0D:C513 + (country-1)*8 + skill*0x38`, see docs/05.

## 5. The scene screen ("podium"): driver on the stand + message
There is no multi-car podium. The picture is **one driver leaning on a railing in front of a checkered "TG" wall**, plus a 3-4 line message and, for 1P, a yellow/black label
`PLAYER 1  <place>` above the driver (two labels and two drivers in 2P).
* Graphics, all in `results_flow` 0F:84F5-8532: `0D:AE51` -> VRAM $2200 (driver/ wall tiles), `0D:C24B` -> WRAM `$7E2000` (a 8x19-tile tilemap strip, the *frames* of the driver),
  `0F:BBA7` -> VRAM $1000 (font for the message). Palette: `0E:FD66` (`load_results_palette` 0F:8705, 16 colours), black fade in/out with `fade_in_dma` / `fade_out_dma`.
* The scene is composed by **`draw_country_flag` 0F:914E** (a misleading name inherited from the main menu, where it draws the country flag; here A selects the driver): it writes
  the wall tiles with `draw_flag_tiles` (0F:911C, 8 columns x 19 rows copied from `$7E2000` into the BG tilemap buffer `$0C6C+Y`) and then the driver with `sub_0F9102` (0F:9102):
  * A = **0 or 3** (qualified / completed the game): tile base `$25`, strip offset `$0130`: **the celebrating driver** (arm raised, green wreath, champagne bottle);
  * A = **1 or 2** (failed): tile base `$A1`, offset `$0260`: **the sad driver** (arms crossed on the railing, looking down).
  In 2P both halves are drawn (palette base $0D20 for player 2) using the same A.
* Message strings (ROM 0F:B1C7..B2F3, `draw_string` format: row byte, column byte, ASCII, 0 ... 0 terminator for the list), 0F:8551 picks them with A:

| A | strings | music (`play_music`) |
|---|---|---|
| 0 | "CONGRATULATIONS / YOU QUALIFIED FOR THE NEXT COUNTRY / PASSWORD xxxxxxxx" (B1C7) | 5 |
| 1 | "SORRY / YOU FAILED TO QUALIFY FOR / THE NEXT RACE" (B23B) | none (menu music keeps playing) |
| 2 | "SORRY / YOU FAILED TO QUALIFY FOR / THE NEXT COUNTRY / PASSWORD ..." (B202) | none |
| 3 | "CONGRATULATIONS / ON COMPLETING TOP GEAR" (B271) + amateur: "BUT CAN YOU WIN ON PROFESSIONAL LEVEL" (B29E), professional: "... CHAMPIONSHIP LEVEL" (B2CA), championship: nothing more | 6 |

  (the place labels are drawn by `draw_result_row` 0F:8693 with suffix ST/ND/RD/TH from `$1FF8`/`$1FFA`; in 2P both labels are drawn, the order depends on which player placed better, not traced further.)
* Then `wait_input_long` (0F:9EAC), fade out and the A-dependent exit above.

## 6. Hooks for a hack
* To make a failure harmless (e.g. a randomizer with no championship): patch `qualify_check_1p` (0F:871A) to `CLC; RTS` and `advance_track` (0F:8733) end to return carry clear. The randomizer already
  bypasses all of this, see docs/09 / docs/10 (`0F:8487`: results -> main menu).
* Different thresholds: the top-5 count is the `LDY #$0004` at 0F:871D; the top-3 count is the `LDY #$0002` at 0F:8759 (0F:875E loop start; the compare chain uses Y as the last index).
* Point values: 10 bytes at ROM 0E:8024 (file offset 0x70024).
* Different scenes per outcome: A is just the table selector in `draw_country_flag`; the two driver frames live in the strip `0D:C24B` (tile ids `$25..` / `$A1..`).

## How to reproduce (agent recipe)
```
TAG=a PLACE=5 TRACK=1 MAXF=6000 tools/mesen.sh scripts/race_end_force.lua | grep -v Uninit      # mid-country fail (6th)
TAG=b PLACE=0 TRACK=3 MAXF=4300 tools/mesen.sh scripts/race_end_force.lua                         # country passed (1st, only 4th race)
TAG=c PLACE=4 TRACK=3 PTS="0,0,90,80,70,60,50,40,30,20,0,0,0,0,0,0,0,0,0,0" ...                 # country fail (9th in standings)
TAG=d PLACE=0 TRACK=31 DIFF=0 ...                                                                 # completed the game
python3 -I tools/contact_sheet.py a 4 330 660 out/a.png                                          # frames out/a_<n>.png as a grid
```
The script starts a real 1P race through the menus, then at frame 3300 (on the next execution of 00:877D, M=0 and DP=0 are guaranteed there) writes `$1F12` (finish list, the human at `PLACE`),
`$1F26`, `$1EB0=10`, `$1F00`, optional `$1F4E` points, `$1F06`, `$1F10` and sets PC to 00:8834 (`race_exit`). Do **not** set PC from `endFrame`: an NMI is taken first and RTI restores
the old M/X flags, which mis-decodes the 16-bit loads (we saw `$1FF6=$0080` garbage that way). It prints the flow with PC hooks (`FAIL_RACE`, `FAIL_COUNTRY`, `WIN_COUNTRY`, `msg0..2`, `set_flag`, `title_screen`, ...)
and `STATE` lines (`$1F06`, `$1F08`, unlock `$1F0A..`) and presses A every 1.5 s to get through the wait-for-key screens.
