dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local wr=emu.memType.snesWorkRam
local mt=emu.memType.snesMemory
local SEED=0x12345678
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function r2(a) return emu.read(a,wr)|(emu.read(a+1,wr)<<8) end
R.steer=function(f) return {x=true} end
R.run(3200,function(f)
  if f<=2 then w2(0x1F800,SEED&0xFFFF) w2(0x1F802,(SEED>>16)&0xFFFF) end
  if f==3100 then
    local t={}
    for a=0x1F800,0x1083E,2 do t[#t+1]=string.format("%04X",r2(a)) end
    print("7F0800:",table.concat(t," "))
    print(string.format("1E56=%04X 1F06=%04X 0200=%04X 1EF0=%04X 1EF2=%04X",r2(0x1E56),r2(0x1F06),r2(0x200),r2(0x1EF0),r2(0x1EF2)))
  end
end)
