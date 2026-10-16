-- Teleport the player along the lap of a generated track and take screenshots (contact sheet input).  env: SEED, N (shots), TAG
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory
local wr=emu.memType.snesWorkRam
local SEED=tonumber(os.getenv("SEED") or "12345678",16)
local N=tonumber(os.getenv("N") or 12)
local TAG=os.getenv("TAG") or string.format("%08X",SEED)
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
local function mw(a,v) emu.write(a,v&0xFF,mt) emu.write(a+1,(v>>8)&0xFF,mt) end
local k=0
R.steer=function(f) return {} end
R.run(3100+N*40+60,function(f)
  if f<=2 then w2(0x1F800,SEED&0xFFFF) w2(0x1F802,(SEED>>16)&0xFFFF) end
  if f>=3200 and (f-3200)%40==0 and k<N then
    local len=rw(0x200)
    local p=(k*len//N+len-200)%len
    -- player 1 record progress and position word
    local slot=rw(0x204)
    mw(0x200+slot+7,p) emu.write(0x200+slot+6,0,mt)
    mw(0x1ED7,p)
    mw(0x200+slot+2,0)       -- lateral 0
    mw(0x1E8A,0)
    k=k+1
  end
  if f>=3200+20 and (f-3220)%40==0 and k>=1 and k<=N then
    local fh=io.open(string.format(os.getenv("TG_ROOT").."/out/tele_%s_%02d.png",TAG,k-1),"wb")
    fh:write(emu.takeScreenshot()) fh:close()
  end
end)
