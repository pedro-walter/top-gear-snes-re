dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory
local TRACK=tonumber(os.getenv("TRACK") or 0)
local out=io.open(os.getenv("TG_ROOT").."/out/vramw.txt","w")
local lastaddr=nil
emu.addMemoryCallback(function(addr,val)
  local s=emu.getState()
  local pc=(s["cpu.k"]<<16)|s["cpu.pc"]
  out:write(string.format("f=%d W2116=%02X pc=%06X\n",R.f,val,pc))
end, emu.callbackType.write, 0x2116)
emu.addMemoryCallback(function(addr,val)
  local s=emu.getState()
  local pc=(s["cpu.k"]<<16)|s["cpu.pc"]
  out:write(string.format("f=%d W2117=%02X pc=%06X\n",R.f,val,pc))
end, emu.callbackType.write, 0x2117)
emu.addMemoryCallback(function(addr,val)
  local s=emu.getState()
  local pc=(s["cpu.k"]<<16)|s["cpu.pc"]
  local m={}
  for ch=0,7 do if (val>>ch)&1==1 then
    local b=0x4300+ch*16
    m[#m+1]=string.format("ch%d src=%02X:%02X%02X len=%02X%02X dst=%02X mode=%02X",ch,emu.read(b+4,mt),emu.read(b+3,mt),emu.read(b+2,mt),emu.read(b+6,mt),emu.read(b+5,mt),emu.read(b+1,mt),emu.read(b,mt)) end end
  out:write(string.format("f=%d W420B=%02X pc=%06X %s\n",R.f,val,pc,table.concat(m," | ")))
end, emu.callbackType.write, 0x420B)
R.steer=function(f) return {} end
R.run(2700,function(f)
  if f>=2000 and f<2400 then emu.write(0x1F06,TRACK,mt) end
end,function() out:close() end)
