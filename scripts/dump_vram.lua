dofile("./scripts/common.lua")
local mt=emu.memType.snesMemory
local TRACK=tonumber(os.getenv("TRACK") or 0)
local FR={[tonumber(os.getenv("F1") or 3300)]=true}
local function dump(name,mtype,n)
  local fh=io.open("./out/"..name,"wb")
  for a=0,n-1 do fh:write(string.char(emu.read(a,mtype))) end
  fh:close()
end
R.steer=function(f) return {} end
R.run(3320,function(f)
  if f>=2000 and f<2400 then emu.write(0x1F06,TRACK,mt) end
  if FR[f] then
    dump("vram_"..f..".bin",emu.memType.snesVideoRam,0x10000)
    dump("cgram_"..f..".bin",emu.memType.snesCgRam,0x200)
    dump("oam_"..f..".bin",emu.memType.snesSpriteRam,0x220)
    local s=emu.getState()
    local fh=io.open("./out/ppu_"..f..".txt","w")
    local keys={} for k,_ in pairs(s) do if k:find("^ppu") then keys[#keys+1]=k end end
    table.sort(keys) for _,k in ipairs(keys) do fh:write(k.."="..tostring(s[k]).."\n") end fh:close()
    local sh=io.open("./out/vs_"..f..".png","wb") sh:write(emu.takeScreenshot()) sh:close()
  end
end)
