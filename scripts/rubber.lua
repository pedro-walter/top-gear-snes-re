dofile("./scripts/common.lua")
local mt=emu.memType.snesMemory
local function rb(a) return emu.read(a,mt) end
local function rw(a) return rb(a)|(rb(a+1)<<8) end
local function ww(a,v) emu.write(a,v&0xFF,mt) emu.write(a+1,(v>>8)&0xFF,mt) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
local DIFF=tonumber(os.getenv("DIFF") or 0)
local fh=io.open("./out/rubber_"..DIFF..".csv","w")
fh:write("f,top,gear2,lapC,lapP,cam59,cam46,fuel2,spd2,spdP,posC,posP,dif\n")
emu.addMemoryCallback(function()
  if R.f<3000 then return end
  fh:write(table.concat({R.f,rw(0x1EE2),rw(0x1E74),rw(0x1E78),rw(0x1E76),rw(0x59),rw(0x46),rw(0x1E64),sw(rw(0x1E5C)),sw(rw(0x1E5A)),rw(0x1EDA),rw(0x1ED7),rw(0x1F10)},","),"\n")
end, emu.callbackType.exec, 0x05EE96, 0x05EE96)
R.steer=function(f) local ph=(f//70)%2 local t={x=true} if ph==0 then t.left=true else t.right=true end return t end
R.run(tonumber(os.getenv("MAXF") or 9000),function(f)
  if f==3000 then ww(0x1F7A,0) ww(0x1F7C,0) ww(0x1F10,DIFF) end
  if f>=3000 then ww(0x1E8A,0) end
end,function() fh:close() end)
