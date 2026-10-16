#!/bin/bash
# usage: tools/rando_vis.sh frame seed...  - race screenshots out/vis_<seed>_<frame>.png (autopilot, headless)
cd "$(dirname "$0")/.."
F=$1; shift
for s in "$@"; do
  TG_ROM=$PWD/out/rando.sfc SEED=$s EXP=none TAG=vis_$s MAXF=$((F+5)) SHOTS=$F tools/mesen2.sh scripts/rando_exp.lua >/dev/null 2>&1
done
