dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
-- equilibrium speed per gear: accelerate only vs accelerate+brake, car parked on a flat, straight stretch
local out=io.open(os.getenv("TG_ROOT").."/out/brake_eq.txt","w")
local function ww(a,v) emu.write(a,v&0xFF,emu.memType.snesMemory) emu.write(a+1,(v>>8)&0xFF,emu.memType.snesMemory) end
local function s16(v) if v>=0x8000 then return v-0x10000 end return v end
local K
local function findflat()
  for k=8,1000 do
    local ok=true
    for j=0,11 do if s16(R.rw(0x7E4000+2*(k+j)))~=0 or s16(R.rw(0x7E4C00+2*(k+j)))~=0 then ok=false break end end
    if ok then return k+2 end
  end
end
local trials={}
for g=0,4 do for _,m in ipairs{"x","xy"} do trials[#trials+1]={g=g,m=m} end end
local T=400
R.steer=function(f)
  local i=(f-3200)//T+1; local tr=trials[i]
  if not tr or f<3200 then return {x=true} end
  local p={x=true}; if tr.m=="xy" then p.y=true end
  return p
end
local log={}
R.run(3200+T*#trials,function(f)
  if f<3150 then return end
  if not K then K=findflat() out:write("flat at word "..tostring(K).."\n") end
  if f<3200 then return end
  local i=(f-3200)//T+1; local k=(f-3200)%T
  local tr=trials[i]; if not tr then return end
  ww(0x1ED6,0) ww(0x1ED7,K*32+4)
  ww(0x1E8A,0) ww(0x1E7E,0) ww(0x1E82,0)
  ww(0x1E72,tr.g)
  if k==0 then local rp=R.rw(0x1E5E) end
  ww(0x1E62,30000)
  if k==0 then ww(0x1E5A,8000) ww(0x1E5E,R.rw(0x1E5E)) log={} end
  if k%50==49 then log[#log+1]=R.rw(0x1E5A) end
  if k==T-1 then out:write(string.format("gear=%d mode=%s fuel=%d top=%d spd: %s\n",tr.g+1,tr.m,R.rw(0x1E62),R.rw(0x1EE2),table.concat(log," "))) end
end,function() out:close() end)
