dofile("./scripts/common.lua")
local mt=emu.memType.snesMemory
local out=io.open("./out/vramw6.txt","w")
local seenf={}
local function dm()
  local m={}
  for ch=0,7 do local b=0x4300+ch*16
    local len=emu.read(b+5,mt)|(emu.read(b+6,mt)<<8)
    m[#m+1]=string.format("ch%d %02X:%02X%02X len=%04X b=%02X mode=%02X",ch,emu.read(b+4,mt),emu.read(b+3,mt),emu.read(b+2,mt),len,emu.read(b+1,mt),emu.read(b,mt)) end
  return table.concat(m," | ")
end
emu.addMemoryCallback(function(addr,val)
  local s=emu.getState()
  local va=s["ppu.vramAddress"]
  if va>=0x910 and va<0xA22 and R.f>=1400 and R.f<2420 then
    local k=R.f.."_"..tostring(va//64)
    if not seenf[k] and #k>0 then seenf[k]=true
      out:write(string.format("f=%d vramaddr=%s inc=%s\n  %s\n",R.f,tostring(s["ppu.vramAddress"]),tostring(s["ppu.vramIncrementValue"]),dm())) end
  end
end, emu.callbackType.write, 0x2119)
R.steer=function(f) return {} end
R.run(2365,nil,function() out:close() end)
