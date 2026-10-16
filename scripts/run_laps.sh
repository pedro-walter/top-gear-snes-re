#!/bin/bash
cd "$(dirname "$0")/.."
for t in $(seq ${START:-0} 31); do TRACK=$t tools/mesen.sh scripts/trk_lap.lua >/dev/null 2>&1; done
echo done > out/lap/done.txt
