#!/bin/bash
# Headless Mesen2 runner. Usage: tools/mesen.sh script.lua   (ROM is fixed)
# LD_PRELOAD works around std::bad_cast in MesenCore.so static init (std::regex vs. static libstdc++).
# HOME is isolated so the user's real ~/.config/Mesen2 is untouched.
D="$(cd "$(dirname "$0")/.." && pwd)"
export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libstdc++.so.6
export HOME="$D/tools/mesen-home2"
sed -i 's/"AllowIoOsAccess": false/"AllowIoOsAccess": true/; s/"ScriptTimeout": [0-9]*/"ScriptTimeout": 30/' "$HOME/.config/Mesen2/settings.json"
cd "$D"
exec "$D/tools/mesen/Mesen" --testRunner "$D/Top Gear (USA).sfc" "$@"
