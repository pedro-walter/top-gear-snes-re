#!/bin/bash
cd "$(dirname "$0")/.."
for t in $(seq 0 31); do TRACK=$t tools/mesen2.sh scripts/dump_sky.lua >/dev/null 2>&1; done
echo done > out/sky_done2.txt
