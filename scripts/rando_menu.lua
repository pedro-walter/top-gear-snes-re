-- Menu test on the randomizer ROM: title -> main menu -> SEED entry (type SEEDHEX, default 1A2B3C4D) -> PLAY GAME -> splash -> race.
-- env: HEX (digits to type, uppercase hex), MAXF, SHOTS (comma list of frames), TAG
local ROOT=os.getenv("TG_ROOT")
local mt=emu.memType.snesMemory
local wr=emu.memType.snesWorkRam
local HEX=os.getenv("HEX") or "1A2B3C4D"
local MAXF=tonumber(os.getenv("MAXF") or 3600)
local TAG=os.getenv("TAG") or "menu"
local shots={}
for s in (os.getenv("SHOTS") or ""):gmatch("%d+") do shots[tonumber(s)]=true end
local function r2(a) return emu.read(a,wr)|(emu.read(a+1,wr)<<8) end
local sched={}   -- frame -> button
local function press(f,b) for i=0,5 do sched[f+i]=b end end
local f=1300
press(f,"start") f=f+120 press(f,"start") f=f+180     -- title -> main menu
local function key(b) press(f,b) f=f+24 end
if os.getenv("TWO") then key("right") end
key("down") key("down") key("a") f=f+120                -- entry 2 (SEED), open the keypad
local cur_r,cur_c=0,0
local HEXC="0123456789ABCDEF"
for i=1,#HEX do
  local ch=HEX:sub(i,i) local k=HEXC:find(ch,1,true)-1
  local r,c=k//6,k%6
  while cur_c<c do key("right") cur_c=cur_c+1 end
  while cur_c>c do key("left") cur_c=cur_c-1 end
  while cur_r<r do key("down") cur_r=cur_r+1 end
  while cur_r>r do key("up") cur_r=cur_r-1 end
  key("a")
end
SHOT_KEYPAD=f
f=f+30
-- go to END (row 4, col 4): down to row 4 then right
key("start") f=f+200
SHOT_MENU=f
key("down") key("down") key("down") key("down") key("a")   -- main menu restarts at entry 0: PLAY GAME = 4 downs

emu.addEventCallback(function()
  local p={}
  local b=sched[FR]
  if b then p[b]=true end
  if FR>=4500 then p.x=true end
  emu.setInput(p,0)
end, emu.eventType.inputPolled)
FR=0
emu.addEventCallback(function()
  FR=FR+1
  if shots[FR] or FR==SHOT_KEYPAD or FR==SHOT_MENU or FR==SHOT_MENU+150 or FR==SHOT_MENU+300 or FR==SHOT_MENU+500 then
    local fh=io.open(ROOT.."/out/"..TAG.."_"..FR..".png","wb") fh:write(emu.takeScreenshot()) fh:close()
  end
  if os.getenv("DUMPVRAM") and FR==SHOT_KEYPAD then
    local fh=io.open(ROOT.."/out/vram_keypad.bin","wb") for a=0,0xFFFF do fh:write(string.char(emu.read(a,emu.memType.snesVideoRam))) end fh:close()
    local st=emu.getState() local keys={} for k,_ in pairs(st) do if k:find("^ppu%.") and (k:find("chr") or k:find("tilemap") or k:find("bgMode") or k:find("layers")) then keys[#keys+1]=k end end table.sort(keys) for _,k in ipairs(keys) do print(k,st[k]) end
    local fh2=io.open(ROOT.."/out/cgram_keypad.bin","wb") for a=0,0x1FF do fh2:write(string.char(emu.read(a,emu.memType.snesCgRam))) end fh2:close()
  end
  if os.getenv("DUMPF") and FR==tonumber(os.getenv("DUMPF")) then
    local nz=0 for a=0x7000,0x77FF do if emu.read(a,wr)~=0 then nz=nz+1 end end print("7E7000 region nonzero:",nz)
    local nz2=0 for a=0x2000,0x5FFF do if emu.read(a,wr)~=0 then nz2=nz2+1 end end print("7E2000-5FFF nonzero:",nz2)
    local fh=io.open(ROOT.."/out/vram_dump.bin","wb") for a=0,0xFFFF do fh:write(string.char(emu.read(a,emu.memType.snesVideoRam))) end fh:close()
    local t={} for i=0,127 do local a=i*4 local x=emu.read(a,emu.memType.snesSpriteRam) local y=emu.read(a+1,emu.memType.snesSpriteRam) local tl=emu.read(a+2,emu.memType.snesSpriteRam) local at=emu.read(a+3,emu.memType.snesSpriteRam) if y<224 then t[#t+1]=string.format("%d:(%d,%d) t=%02X a=%02X",i,x,y,tl,at) end end
    print(table.concat(t,"\n"))
  end
  if FR%500==0 then
    local s=emu.getState()
    print(string.format("%d seed=%04X%04X track=%d laps=%d pc=%02X:%04X",FR,r2(0x1F802),r2(0x1F800),emu.read(0x1F06,mt),emu.read(0x1E56,mt),s["cpu.k"],s["cpu.pc"]))
  end
  if FR>=MAXF then print("END",string.format("seed=%04X%04X",r2(0x1F802),r2(0x1F800))) emu.stop(0) end
end, emu.eventType.endFrame)
