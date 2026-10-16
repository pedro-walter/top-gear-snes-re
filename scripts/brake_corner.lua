dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
-- Hold the car at a fixed place inside a constant-curvature run at a fixed speed and see whether
-- steering fully into the corner can cancel the centrifugal push (accelerate / accelerate+brake / coast).
local out=io.open(os.getenv("TG_ROOT").."/out/brake_corner.txt","w")
local RUNS={[16]=132+40,[24]=453+30,[32]=550+4}   -- curve value -> first word index (inside run)
local function ww(a,v) emu.write(a,v&0xFF,emu.memType.snesMemory) emu.write(a+1,(v>>8)&0xFF,emu.memType.snesMemory) end
local trials={}
for _,c in ipairs{24,32} do for _,spd in ipairs{5000,6000,7000,8000,9000,10000,11000,12000,13000} do
  for _,mode in ipairs{"x","xy","none"} do for _,st in ipairs{"left"} do
    trials[#trials+1]={c=c,spd=spd,mode=mode,st=st}
  end end end end
local T=40
R.steer=function(f)
  local i=(f-3200)//T+1
  local tr=trials[i]; if not tr or f<3200 then return {x=true} end
  local p={}
  if tr.mode=="x" or tr.mode=="xy" then p.x=true end
  if tr.mode=="xy" then p.y=true end
  p[tr.st]=true
  return p
end
local last
R.run(3200+T*#trials,function(f)
  if f<3200 then return end
  local i=(f-3200)//T+1; local k=(f-3200)%T
  local tr=trials[i]; if not tr then return end
  local pos=RUNS[tr.c]*32+8
  if k==0 then ww(0x1E8A,0) ww(0x1E7E,0) ww(0x1E82,0) last={} end
  ww(0x1ED6,0) ww(0x1ED7,pos) ww(0x1E5A,tr.spd)
  ww(0x1E62,40000)   -- fuel
  local lat=R.rw(0x1E8A) if lat>=0x8000 then lat=lat-0x10000 end
  last[#last+1]=lat
  if k>0 then ww(0x1E8A,0) end
  if k==T-1 then
    out:write(string.format("c=%d spd=%d mode=%s st=%s lat=%s e94=%d fl=%04X\n",tr.c,tr.spd,tr.mode,tr.st,table.concat(last," ",1,T),R.rw(0x1E94),R.rw(0x1EF5)))
  end
end,function() out:close() end)
