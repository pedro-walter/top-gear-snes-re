dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
-- Loch Ness (30): accelerate+brake held inside a c=+-32 curve on a downhill / flat / uphill stretch.
-- Car parked at a fixed place, speed starts at S0, gear forced, lateral position zeroed every frame (we sum the outward push).
local out=io.open(os.getenv("TG_ROOT").."/out/brake_slope.txt","w")
local function ww(a,v) emu.write(a,v&0xFF,emu.memType.snesMemory) emu.write(a+1,(v>>8)&0xFF,emu.memType.snesMemory) end
local function s16(v) if v>=0x8000 then return v-0x10000 end return v end
local REG={down={w=470,st="left"},flat={w=1230,st="left"},up={w=640,st="right"}}
local trials={}
for _,r in ipairs{"down","flat","up"} do for _,g in ipairs{2,3,4} do for _,m in ipairs{"x","xy"} do
  trials[#trials+1]={r=r,g=g,m=m} end end end
local T=240
local START=3300
R.steer=function(f)
  if f<START then
    if f>=1500 and f<2400 then emu.write(0x1F06,30,emu.memType.snesMemory) end
    return {x=true}
  end
  local tr=trials[(f-START)//T+1]; if not tr then return {} end
  local p={x=true,[REG[tr.r].st]=true}; if tr.m=="xy" then p.y=true end
  return p
end
local log,push
R.run(START+T*#trials,function(f)
  if f>=1500 and f<2400 then ww(0x1F06,30) end
  if f<START then return end
  local i=(f-START)//T+1; local k=(f-START)%T
  local tr=trials[i]; if not tr then return end
  local r=REG[tr.r]
  ww(0x1ED6,0) ww(0x1ED7,r.w*32+8)
  ww(0x1E72,tr.g); ww(0x1E62,30000)
  if k==0 then ww(0x1E5A,9000) log={} push=0 end
  local lat=s16(R.rw(0x1E8A)); if k>=20 then push=push+lat end; ww(0x1E8A,0)
  if k%30==29 then log[#log+1]=R.rw(0x1E5A) end
  if k==T-1 then out:write(string.format("%s gear=%d %s slope=%d curve=%d push=%d spd: %s\n",tr.r,tr.g+1,tr.m,s16(R.rw(0x7E4000+2*r.w)),s16(R.rw(0x7E4C00+2*r.w)),push,table.concat(log," "))) end
end,function() out:close() end)
