-- keypad navigation test: prints KP_CUR ($1FD2), count ($5E) and typed bytes ($68..) after every action
local ROOT=os.getenv("TG_ROOT")
local mt=emu.memType.snesMemory
local sched={} local function press(f,b) for i=0,5 do sched[f+i]=b end end
local f=1300
press(f,"start") f=f+120 press(f,"start") f=f+180
local acts={"down","down","a"}
for _,b in ipairs(acts) do press(f,b) f=f+24 end f=f+160
local seq={ {"up",12},{"up",6},{"up",0},{"left",5},{"right",0},{"down",6},{"down",12},{"down",0},{"left",5},{"up",17},{"right",12},{"left",17},
  {"a",17}  }
-- first run the nav checks, then type 3 keys, delete, B, finish with A on END
local checks={}
for _,e in ipairs(seq) do if e[1]~="a" then press(f,e[1]) checks[f+14]={e[2],"nav "..e[1]} f=f+30 end end
-- go to cell 11 (b): from 17 left x? set via keys: from 17 press up -> 11
press(f,"up") checks[f+14]={11,"up->11"} f=f+30
press(f,"a") checks[f+14]={11,"typed b"} f=f+30
press(f,"left") f=f+30 press(f,"a") checks[f+14]={10,"typed A"} f=f+30
press(f,"b") checks[f+14]={10,"B deletes"} f=f+30
press(f,"a") f=f+30  -- types A again
press(f,"down") f=f+30  -- cell 16 (arrow)
press(f,"a") checks[f+14]={16,"arrow deletes"} f=f+30
press(f,"right") f=f+30 -- cell 17
press(f,"a") f=f+120 -- END
local FR=0
emu.addEventCallback(function() local p={} local b=sched[FR] if b then p[b]=true end emu.setInput(p,0) end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  FR=FR+1
  local c=checks[FR]
  if c then
    local cur=emu.read(0x1FD2,mt)
    local s=string.format("%s: cur=%d (expect %d) count=%d typed=%02X%02X%02X",c[2],cur,c[1],emu.read(0x5E,mt),emu.read(0x68,mt),emu.read(0x69,mt),emu.read(0x6A,mt))
    print((cur==c[1]) and "OK  "..s or "BAD "..s)
  end
  if FR==f then local pc=emu.getState()["cpu.pc"] print(string.format("FINAL pc=%X seed=%02X%02X%02X%02X count=%d",pc,emu.read(0x1F803,emu.memType.snesWorkRam),emu.read(0x1F802,emu.memType.snesWorkRam),emu.read(0x1F801,emu.memType.snesWorkRam),emu.read(0x1F800,emu.memType.snesWorkRam),emu.read(0x5E,mt))) emu.stop(0) end
end, emu.eventType.endFrame)
