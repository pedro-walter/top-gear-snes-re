-- Live overlay of car variables (see docs/). Shown over the sky of the bottom (computer) screen.
-- Load in Mesen2: Debug > Script Window > File > Open > this file > Run.
-- (Mesen can only draw inside the 256x224 frame, so for off-screen readouts use Debug > Watch Window.)
local function r16(a) return emu.read(a, emu.memType.snesWorkRam) | (emu.read(a+1, emu.memType.snesWorkRam) << 8) end
local function s16(v) if v >= 0x8000 then return v - 0x10000 end return v end
local Y0 = 132            -- first text row (sky area of the bottom screen)
local BG = 0xA0000000     -- translucent black
local peak = 0
emu.addEventCallback(function()
  local sp = r16(0x1E5A)
  if sp < 0x8000 and sp > peak then peak = sp end
  local rows = {
    string.format("SPD %5d RPM %5d GR %d", sp, r16(0x1E5E), r16(0x1E72)),
    string.format("FUEL %5d F2? %5d NIT %6d", r16(0x1E62), r16(0x1E64), s16(r16(0x1E6C))),
    string.format("POS %5d FLG %04X TOP %5d", r16(0x1ED7), r16(0x1EF5), r16(0x1EE2)),
    string.format("DIF %2d CAR %d OPP %d BRN %3d EE8 %2d", r16(0x1F10), r16(0x1F8F), r16(0x1FAC), emu.read(0x1EFD, emu.memType.snesWorkRam), r16(0x1EE8)),
    string.format("SHIFT 7A %04X 7C %04X 7E %04X", r16(0x1F7A), r16(0x1F7C), r16(0x1F7E)),
    string.format("PEAK SPD %5d", peak),
  }
  for i, t in ipairs(rows) do emu.drawString(2, Y0 + (i-1)*8, t, 0xFFFF80, BG) end
end, emu.eventType.endFrame)
emu.displayMessage("Script", "overlay.lua loaded")
