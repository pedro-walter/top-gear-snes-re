-- poke the object table right before init_scenery_cache (00:BF26): MODE=all|wrap|none, then screenshot at f=3100
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory local wr=emu.memType.snesWorkRam
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
local MODE=os.getenv("MODE") or "none"
local TAG=os.getenv("TAG") or "g2"
R.steer=function(f) return {x=true} end
emu.addMemoryCallback(function()
  local L=rw(0x200)//32
  local function z(a,b) for i=a,b do local w=emu.read(0x6400+2*i,wr)|(emu.read(0x6401+2*i,wr)<<8) if w<0x8000 then w2(0x6400+2*i,0) end end end
  if MODE=="all" then z(0,L*32+63) end
  if MODE=="wrap" then z(L*32,L*32+63) end
  if MODE=="before" then z(L*32-64,L*32-1) end
  if MODE=="first" then z(0,63) end
  if MODE=="sig" then for i=0,L*32+63 do local w=emu.read(0x6400+2*i,wr)|(emu.read(0x6401+2*i,wr)<<8) local t=(w>>9)&0x7F if w<0x8000 and (t==8 or t==9 or t==13) then w2(0x6400+2*i,0) end end end
  if MODE=="fw" then z(0,63) z(L*32,L*32+63) end
  local C1,C2,C3=MODE:match("^c(%d+)_(%d+)_(%d+)$")   -- zero [0,C1] and [L*32-C2, L*32+C3-1]
  if C1 then z(0,tonumber(C1)) z(L*32-tonumber(C2),L*32+tonumber(C3)-1) end
  local TL=MODE:match("^t([%d_]+)$")
  if TL then local set={} for n in TL:gmatch("%d+") do set[tonumber(n)]=true end
    for i=0,L*32+63 do local w=emu.read(0x6400+2*i,wr)|(emu.read(0x6401+2*i,wr)<<8) local t=(w>>9)&0x7F if w<0x8000 and set[t] then w2(0x6400+2*i,0) end end end
  local T24A,T24B=MODE:match("^u(%d+)_(%d+)$")   -- zero type 24 in [L*32-A, L*32+B-1] only
  if T24A then for i=L*32-tonumber(T24A),L*32+tonumber(T24B)-1 do local w=emu.read(0x6400+2*i,wr)|(emu.read(0x6401+2*i,wr)<<8) if w<0x8000 and ((w>>9)&0x7F)==24 then w2(0x6400+2*i,0) end end end
  local R1,R2=MODE:match("^r(%d+)_(%d+)$")
  if R1 then z(tonumber(R1),tonumber(R2)) end
  local A,B=MODE:match("^w(%d+)_(%d+)$")
  if A then z(L*32-tonumber(A),L*32+tonumber(B)-1) end
  print("POKED",MODE,L)
end, emu.callbackType.exec, 0x00BF26)
R.run(3150,function(f)
  if os.getenv("SEED") and f>=1000 and f<1500 then local S=tonumber(os.getenv("SEED"),16) w2(0x1F800,S&0xFFFF) w2(0x1F802,(S>>16)&0xFFFF) w2(0x1F804,1) w2(0x1F806,0xA55A) end
  if f>3000 and not SHOT then local L=rw(0x200) local pos=rw(0x1ED7) if L>0 and pos>=L-450 and pos<L then SHOT=true
    local o={} for a=0,543 do o[a]=emu.read(a,emu.memType.snesSpriteRam) end
    local Ls={} for i=0,127 do local y=o[4*i+1] if y<112 then local h=(o[512+i//4]>>(2*(i%4)))&3 Ls[#Ls+1]=string.format("%d,%d:%02X/%02X/%d",o[4*i]+((h&1)*256),y,o[4*i+2],o[4*i+3],h>>1) end end
    local fh=io.open(string.format("%s/out/%s_%s_pos.png",os.getenv("TG_ROOT"),TAG,MODE),"wb") fh:write(emu.takeScreenshot()) fh:close() end end
  if f==3100 then local fh=io.open(string.format("%s/out/%s_%s.png",os.getenv("TG_ROOT"),TAG,MODE),"wb") fh:write(emu.takeScreenshot()) fh:close() end
end)
