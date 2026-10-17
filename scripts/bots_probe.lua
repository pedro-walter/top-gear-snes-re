-- Bot probe: per-frame car records (lateral, speed, progress, lap) + every RNG call (PC, frame). Original ROM, hold accelerate.
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local N=tonumber(os.getenv("FR") or 2500)
local mt=emu.memType.snesMemory
local out=io.open(os.getenv("TG_ROOT").."/out/bots_probe.csv","w")
local rl=io.open(os.getenv("TG_ROOT").."/out/bots_rng.csv","w")
out:write("f,pos,len,slotp1,id,lat,latspd,prog,lap,spd\n")
emu.addMemoryCallback(function() rl:write(R.f,",",string.format("%06X",R.pc()),",",string.format("%04X",R.rw(0x1FF4)),"\n") end, emu.callbackType.exec, 0x00A89E, 0x00A89E)
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
R.steer=function(f) return {x=true} end
R.run(3000+N,function(f)
  if f<2990 then return end
  local len=R.rw(0x200)
  for j=0,19 do local b=0x212+18*j
    out:write(f,",",R.rw(0x1ED7),",",len,",",R.rw(0x204)//18,",",R.rw(b)&0x1F,",",sw(R.rw(b+2)),",",sw(R.rw(b+4)),",",R.rw(b+7),",",R.rd(b+9),",",R.rw(b+10),"\n") end
end,function() out:close() rl:close() end)
