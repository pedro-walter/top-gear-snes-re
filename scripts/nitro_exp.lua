-- Nitro experiment: flatten hills/curves, poke start speed & gear policy, press nitro, log speed per frame.
dofile("./scripts/common.lua")
local V0=tonumber(os.getenv("V0") or 0)
local POL=os.getenv("POL") or "f2"     -- f<g> fixed gear index, auto, or seq:<th>:<g>,...
local F0=3150
local fh=io.open("./out/nitro_"..POL:gsub("[:,]","_").."_"..V0..".csv","w")
local mt=emu.memType.snesMemory
local function rb(a) return emu.read(a,mt) end
local function rw(a) return rb(a)|(rb(a+1)<<8) end
local function ww(a,v) emu.write(a,v&0xFF,mt) emu.write(a+1,(v>>8)&0xFF,mt) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
local seq={}
if POL:sub(1,4)=="seq:" then for th,g in POL:sub(5):gmatch("(%d+):(%d+)") do seq[#seq+1]={tonumber(th),tonumber(g)} end end
local tf=io.open("./out/nt_"..POL:gsub("[:,]","_").."_"..V0..".csv","w")
tf:write("f,v,gear,nitro,fuel,pos,slope,top,flag\n")
local entry={}
emu.addMemoryCallback(function() if R.f>=F0 then entry={sw(rw(0x1E5A)),rw(0x1E72),rw(0x1E6C),rw(0x1E62),rw(0x1ED7),rw(0x1EF5)} end end, emu.callbackType.exec, 0x05D2E0, 0x05D2E0)
emu.addMemoryCallback(function() if R.f>=F0 and entry[1] then
  local pos=entry[5] local idx=(pos>>4)&0xFFFE
  tf:write(table.concat({R.f-F0,entry[1],entry[2],entry[3],entry[4],pos,sw(rw(0x7E4000+idx)),rw(0x1EE2),entry[6]},","),"\n") end end, emu.callbackType.exec, 0x05D3F5, 0x05D3F5)
R.steer=function(f)
  local t={x=true}
  if f>=F0+5 and f<F0+9 then t.a=true end
  return t
end
local started=false
R.run(F0+420,function(f)
  if f==2990 then

  end
  if f>=2990 then
    -- flatten: slope + curve tables (WRAM $4000-$5800)
    if f==3100 then for a=0x7E4000,0x7E67FF do emu.write(a,0,mt) end end
    ww(0x1E8A,0) ww(0x1E8E,0)
    -- bots out of the way
    for j=0,19 do local b=0x212+18*j
      if (b-0x212)~=rw(0x204) and (b-0x212)~=rw(0x206) then ww(b+2,0x6000) end end
  end
  if f==F0 then ww(0x1E5A,V0) ww(0x1E62,0xA7FF) ww(0x1E6C,3)
    if POL=="auto" then ww(0x1F7A,0) ww(0x1F7C,0) end
  end
  if f>=F0 then
    local v=sw(rw(0x1E5A))
    if POL:sub(1,1)=="f" then ww(0x1E72,tonumber(POL:sub(2)))
    elseif #seq>0 then local g=seq[1][2] for _,s in ipairs(seq) do if v>=s[1] then g=s[2] end end ww(0x1E72,g) end
    fh:write(table.concat({f-F0,v,rw(0x1E72),rw(0x1E6C),rw(0x1ED7),rw(0x1E5E),rw(0x1EE2)},","),"\n")
  end
end,function() fh:close() tf:close() end)
