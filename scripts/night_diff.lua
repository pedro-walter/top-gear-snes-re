dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
-- Track TRACK: park at several progress values and dump CGRAM + PPU state to see what differs between day and night
local TRACK=tonumber(os.getenv("TRACK") or "9")
local POS={}; for p in (os.getenv("POS") or "10000,20000"):gmatch("%d+") do POS[#POS+1]=tonumber(p) end
local out=io.open(os.getenv("TG_ROOT").."/out/night_diff_"..TRACK..".txt","w")
local function ww(a,v) emu.write(a,v&0xFF,emu.memType.snesMemory) emu.write(a+1,(v>>8)&0xFF,emu.memType.snesMemory) end
R.steer=function(f)
  if f>=1500 and f<2400 then emu.write(0x1F06,TRACK,emu.memType.snesMemory) end
  return {x=true}
end
local START,T=3300,150
R.run(START+T*#POS,function(f)
  if f>=1500 and f<2400 then ww(0x1F06,TRACK) end
  if f<START then return end
  local i=(f-START)//T+1; local k=(f-START)%T
  if not POS[i] then return end
  ww(0x1ED6,0) ww(0x1ED7,POS[i]); ww(0x1E8A,0); ww(0x1E5A,3000)
  if k==T-1 then
    local fh=io.open(os.getenv("TG_ROOT").."/out/night_"..TRACK.."_"..POS[i]..".png","wb") fh:write(emu.takeScreenshot()) fh:close()
    local cg={}
    for a=0,511 do cg[#cg+1]=string.format("%02X",emu.read(a,emu.memType.snesCgRam)) end
    out:write("POS "..POS[i].."\nCGRAM "..table.concat(cg).."\n")
    local s=emu.getState()
    local keys={} for k2,v in pairs(s) do if k2:sub(1,4)=="ppu." then keys[#keys+1]=k2 end end
    table.sort(keys)
    for _,k2 in ipairs(keys) do out:write(k2.."="..tostring(s[k2]).."\n") end
  end
end,function() out:close() end)
