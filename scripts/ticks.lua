dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local fh=io.open(os.getenv("TG_ROOT").."/out/ticks_"..(os.getenv("TAG") or "a")..".csv","w")
local function rb(a) return emu.read(a,emu.memType.snesMemory) end
local function rw(a) return rb(a)|(rb(a+1)<<8) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
fh:write("f,spd,gear,nitro,fuel,pos,top,flag,slope,rpm,joy\n")
emu.addMemoryCallback(function(a,v)
  if R.f<2950 then return end
  local pos=rw(0x1ED7)
  local sl=0
  fh:write(table.concat({R.f,sw(rw(0x1E5A)),rw(0x1E72),rw(0x1E6C),rw(0x1E62),pos,rw(0x1EE2),rw(0x1EF5),
     sw(emu.read(0x7E4000+((pos>>4)&0xFFFE),emu.memType.snesMemory)|(emu.read(0x7E4000+((pos>>4)&0xFFFE)+1,emu.memType.snesMemory)<<8)),rw(0x1E5E),rw(0x14)},","),"\n")
end, emu.callbackType.exec, 0x05D2E0, 0x05D2E0)
R.steer=function(f) local t={x=true}
  if f==3100 or f==5000 then t.a=true end
  return t end
R.run(tonumber(os.getenv("MAXF") or 5600),nil,function() fh:close() end)
