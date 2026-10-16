-- gantry experiment on ORIGINAL track TRACK (or seed with SEED): poke curve CUR / slope SLO words on the last 3 pieces before the line
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory local wr=emu.memType.snesWorkRam
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
local TAG=os.getenv("TAG") or "g"
R.steer=function(f) return {x=true} end
R.run(3200,function(f)
  if os.getenv("TRACK") and f>=2000 and f<2400 then emu.write(0x1F06,tonumber(os.getenv("TRACK")),mt) end
  if os.getenv("SEED") and f>=1000 and f<1500 then local S=tonumber(os.getenv("SEED"),16) w2(0x1F800,S&0xFFFF) w2(0x1F802,(S>>16)&0xFFFF) w2(0x1F804,1) w2(0x1F806,0xA55A) end
  if f==3030 then
    local L=rw(0x200)//32
    local C=tonumber(os.getenv("CUR") or 0) local S=tonumber(os.getenv("SLO") or 0)
    for i=(L-3)*32,L*32+63 do if C~=0 then w2(0x4C00+2*i,C) end if S~=0 then w2(0x4000+2*i,S) end end
  end
  if f==3100 or f==3140 then local fh=io.open(string.format(os.getenv("TG_ROOT").."/out/%s_%d.png",TAG,f),"wb") fh:write(emu.takeScreenshot()) fh:close() end
end)
