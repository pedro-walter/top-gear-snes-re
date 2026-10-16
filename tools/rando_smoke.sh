#!/bin/bash
# usage: tools/rando_smoke.sh seed...   (hex seeds) - runs each seed headless for ~5000 frames, prints SMOKE lines
cd "$(dirname "$0")/.."
for s in "$@"; do
  TG_ROM=$PWD/out/rando.sfc SEED=$s tools/mesen2.sh scripts/rando_smoke.lua 2>&1 | grep SMOKE
done
