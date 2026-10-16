dofile("./scripts/common.lua")
local mt=emu.memType.snesMemory
local function rb(a) return emu.read(a,mt) end
local function rw(a) return rb(a)|(rb(a+1)<<8) end
local function ww(a,v) emu.write(a,v&0xFF,mt) emu.write(a+1,(v>>8)&0xFF,mt) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
local TRACK=tonumber(os.getenv("TRACK") or 3)
local FUEL=tonumber(os.getenv("FUEL") or 0x2000)
local FSET=tonumber(os.getenv("FSET") or 3300)
local fh=io.open("./out/pit_"..TRACK..".csv","w")
fh:write("f,cpos,clat,cfuel,cspd,cgear,pit88,flag2,ef0,lapC,lapP,pos\n")
R.steer=function(f) return {x=true} end
R.run(tonumber(os.getenv("MAXF") or 7000),function(f)
  if f>=2000 and f<2400 then ww(0x1F06,TRACK) end
  if f==FSET then ww(0x1E64,FUEL) end
  if f>=2940 and f%5==0 then
    fh:write(table.concat({f,rw(0x1EDA),sw(rw(0x1E8C)),rw(0x1E64),sw(rw(0x1E5C)),rw(0x1E74),rw(0x1E88),rw(0x1EF2),rw(0x1EF0),rw(0x1E78),rw(0x1E76),rw(0x1ED7)},","),"\n")
  end
end,function() fh:close() end)
