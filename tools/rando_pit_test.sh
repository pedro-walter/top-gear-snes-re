#!/bin/bash
# usage: tools/rando_pit_test.sh "seed target" ...   - drives the human car into the pit lane, prints the pit state changes
cd "$(dirname "$0")/.."
for a in "$@"; do
  set -- $a
  echo "== seed $1 target $2"
  TG_ROM=$PWD/out/rando.sfc SEED=$1 TARGET=$2 MAXF=${MAXF:-8500} tools/mesen2.sh scripts/rando_pit_human.lua 2>&1 | grep -E "pit_state_p1=(FFFF|FFFE|FFF5|0000) " | head -4
done
