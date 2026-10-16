dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local out=io.open(os.getenv("TG_ROOT").."/out/cm_probe.txt","w")
R.steer=function(f) if f>=1500 and f<2400 then emu.write(0x1F06,9,emu.memType.snesMemory) end return {x=true} end
R.run(3200,function(f)
  if f>=1500 and f<2400 then emu.write(0x1F06,9,emu.memType.snesMemory) end
  if f==3150 then
    local s=emu.getState()
    for k,v in pairs(s) do if k:find("olorMath") or k:find("fixedColor") or k:find("colorMath") or k:find("mainScreen") or k:find("subScreen") or k:find("windowMask") or k:find("screenBrightness") then out:write(k.."="..tostring(v).."\n") end end
    out:write(string.format("0100=%04X\n",R.rw(0x100)))
  end
end,function() out:close() end)
