-- Runs the on-console generator (harness ROM) for the seeds in out/rando_seeds.txt and dumps the results to out/rando_dump.bin.
local ROOT=os.getenv("TG_ROOT")
dofile(ROOT.."/out/rando_harness.lua")
local seeds={}
for l in io.lines(ROOT.."/out/rando_seeds.txt") do seeds[#seeds+1]=tonumber(l,16) end
local M=emu.memType.snesWorkRam
local function rd(a) return emu.read(a,M) end
local function rw(a) return emu.read(a,M)|(emu.read(a+1,M)<<8) end
local function ww(a,v) emu.write(a,v&0xFF,M) emu.write(a+1,(v>>8)&0xFF,M) end
local out=io.open(ROOT.."/out/rando_dump.bin","wb")
local i=0
local function dump(base,n)
  local t={}
  for k=0,n-1 do t[#t+1]=string.char(rd(base+k)) end
  out:write(table.concat(t))
end
emu.addMemoryCallback(function()
  i=i+1
  if i>#seeds then out:close() emu.stop(0) return end
  local s=seeds[i]
  ww(0x1F800,s&0xFFFF) ww(0x1F802,(s>>16)&0xFFFF)
end, emu.callbackType.exec, SYM.h_loop)
emu.addMemoryCallback(function()
  if i<1 or i>#seeds then return end
  local P=rw(0x1F834)
  out:write(string.pack("<I4I2I2I2I2I2",seeds[i],rw(0x1F830),rw(0x1F832),rw(0x1F836),rw(0x1F83E),P))
  dump(0x4000,P*64) dump(0x4C00,P*64) dump(0x5800,P*64) dump(0x6400,P*64) dump(0x1F000,96) dump(0x1F080,96)
end, emu.callbackType.exec, SYM.h_done)
emu.addEventCallback(function() end, emu.eventType.endFrame)
