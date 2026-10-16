-- force the player pit sequence by poking $1E86=FFFF at frame FORCE; screenshots every 30 frames after. ORIGINAL ROM: TRACK=n ; rando ROM: SEED=hex
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory local wr=emu.memType.snesWorkRam
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
local TAG=os.getenv("TAG") or "pf"
local FORCE=tonumber(os.getenv("FORCE") or 3600)
R.steer=function(f) return {x=true} end
R.run(FORCE+700,function(f)
  if os.getenv("TRACK") and f>=2000 and f<2400 then emu.write(0x1F06,tonumber(os.getenv("TRACK")),mt) end
  if os.getenv("SEED") and f>=1000 and f<1500 then local S=tonumber(os.getenv("SEED"),16) w2(0x1F800,S&0xFFFF) w2(0x1F802,(S>>16)&0xFFFF) w2(0x1F804,1) w2(0x1F806,0xA55A) end
  if f==FORCE then w2(0x1E86,0xFFFF) end
  if f==FORCE+120 and os.getenv("DUMP") then
    local o={} for a=0,543 do o[a]=emu.read(a,emu.memType.snesSpriteRam) end
    local L={} for i=0,127 do local y=o[4*i+1] if y<112 then local h=(o[512+i//4]>>(2*(i%4)))&3 L[#L+1]=string.format("%d(%d,%d t%02X a%02X h%d)",i,o[4*i],y,o[4*i+2],o[4*i+3],h) end end
    print("OAM",#L,table.concat(L," "))
  end
  if f==FORCE+120 and os.getenv("DUMP") then
    local st=emu.getState() local keys={} for k,_ in pairs(st) do if k:find("^ppu%.") and (k:find("chr") or k:find("tilemap") or k:find("bgMode") or k:find("layers") or k:find("Scroll") or k:find("mosaic")) then keys[#keys+1]=k end end table.sort(keys) for _,k in ipairs(keys) do print("PPU",k,st[k]) end
    print("DP", string.format("52=%02X E0=%02X E1=%02X A6=%04X A8=%04X C8=%04X 40=%04X",emu.read(0x52,wr),emu.read(0xE0,wr),emu.read(0xE1,wr),rw(0xA6),rw(0xA8),rw(0xC8),rw(0x40)))
  end
  if f==FORCE+200 and os.getenv("DUMP") then
    local fh=io.open(os.getenv("DUMP")..".wram","wb") for a=0,0x1FFFF do fh:write(string.char(emu.read(a,wr))) end fh:close()
    local fh=io.open(os.getenv("DUMP")..".vram","wb") for a=0,0xFFFF do fh:write(string.char(emu.read(a,emu.memType.snesVideoRam))) end fh:close()
  end
  if f>=FORCE and (f-FORCE)%40==0 then
    local fh=io.open(string.format("%s/out/%s_%d.png",os.getenv("TG_ROOT"),TAG,f),"wb") fh:write(emu.takeScreenshot()) fh:close()
    print("F",f,string.format("st=%04X sp=%d",rw(0x1E86),rw(0x1E5A)))
  end
end)
