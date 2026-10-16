dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
-- log the lighting state ($0100,$0102,$0104,$0106,$0398) whenever it changes; MODE=park (fixed position) or sweep (pos += STEP/frame)
local TRACK=tonumber(os.getenv("TRACK") or "9")
local MODE=os.getenv("MODE") or "park"
local STEP=tonumber(os.getenv("STEP") or "40")
local FR=tonumber(os.getenv("FRAMES") or "1500")
local out=io.open(os.getenv("TG_ROOT").."/out/light_"..TRACK.."_"..MODE..".txt","w")
local function ww(a,v) emu.write(a,v&0xFF,emu.memType.snesMemory) emu.write(a+1,(v>>8)&0xFF,emu.memType.snesMemory) end
R.steer=function(f)
  if f>=1500 and f<2400 then emu.write(0x1F06,TRACK,emu.memType.snesMemory) end
  return {x=true}
end
local START=3000
local pos=0
local prev=""
R.run(START+FR,function(f)
  if f>=1500 and f<2400 then ww(0x1F06,TRACK) end
  if f<START then return end
  if MODE=="sweep" then pos=pos+STEP if pos>=65000 then pos=0 end ww(0x1ED6,0) ww(0x1ED7,pos) ww(0x1E8A,0) ww(0x1E5A,3000)
  elseif MODE=="park" then ww(0x1ED6,0) ww(0x1ED7,5000) ww(0x1E8A,0) ww(0x1E5A,3000) end
  local s=string.format("0100=%04X 0102=%04X 0104=%04X 0106=%04X",R.rw(0x100),R.rw(0x102),R.rw(0x104),R.rw(0x106))
  if f%25==0 or s:sub(1,9)~=prev:sub(1,9) then out:write(string.format("f=%d pos=%d id=%d %s\n",f-START,R.rw(0x1ED7),R.rw(0x1F06),s)) end
  prev=s
end,function() out:close() end)
