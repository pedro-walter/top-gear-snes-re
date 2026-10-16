dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
-- sweep progress along TRACK (pos += STEP per frame) and log every CGRAM colour change with the position
local TRACK=tonumber(os.getenv("TRACK") or "9")
local STEP=tonumber(os.getenv("STEP") or "40")
local out=io.open(os.getenv("TG_ROOT").."/out/night_sweep_"..TRACK..".txt","w")
local function ww(a,v) emu.write(a,v&0xFF,emu.memType.snesMemory) emu.write(a+1,(v>>8)&0xFF,emu.memType.snesMemory) end
R.steer=function(f)
  if f>=1500 and f<2400 then emu.write(0x1F06,TRACK,emu.memType.snesMemory) end
  return {x=true}
end
local START=3300
local prev
local pos=0
R.run(START+ (46000//STEP)+60,function(f)
  if f>=1500 and f<2400 then ww(0x1F06,TRACK) end
  if f<START then return end
  if f>=START+30 then pos=pos+STEP if pos>=65000 then pos=0 end end
  ww(0x1ED6,0) ww(0x1ED7,pos); ww(0x1E8A,0); ww(0x1E5A,3000)
  local cur={}
  for a=0,255 do cur[a]=emu.read(a*2,emu.memType.snesCgRam)|(emu.read(a*2+1,emu.memType.snesCgRam)<<8) end
  if prev then
    local ch={}
    for a=0,255 do if cur[a]~=prev[a] then ch[#ch+1]=string.format("%d:%04X>%04X",a,prev[a],cur[a]) end end
    if #ch>0 then out:write(string.format("f=%d pos=%d %s\n",f-START,pos,table.concat(ch," "))) end
  end
  prev=cur
end,function() out:close() end)
