-- counts the scanner's failed graphics loads (00:E3BF) over one lap of seed SEED (hex) or original TRACK; prints "DET ..." and the first DROP states.  Companion of tools/pool_model.py
-- detector: count VRAM-allocator failure paths of scan_roadside_objects during one lap of seed SEED (or original TRACK)
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory local wr=emu.memType.snesWorkRam
local SEED=os.getenv("SEED") and tonumber(os.getenv("SEED"),16)
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
R.steer=function(f) local lat=sw(rw(0x1E8A)) local t={x=true} if lat>1200 then t.left=true elseif lat<-1200 then t.right=true end return t end
local drops,fulls,maxn={},{},0
local wraps,last=0,0
local function pos() return rw(0x1ED7)//32 end
local shown=0
emu.addMemoryCallback(function() if wraps>=1 then drops[#drops+1]=pos()
  if shown<6 and (#drops==1 or drops[#drops]-drops[#drops-1]>40) then shown=shown+1
    local n=rw(0x1BE6) local l={}
    for i=0,n-1 do local id=rw(0x1BE8+2*i) l[#l+1]=string.format("id%d[%d..%d)",id,rw(0x1C08+id),rw(0x1C88+id)) end
    local pend={} local x=rw(0x1BC2) while x~=rw(0x1BC4) do pend[#pend+1]=rw(0x1BC6+x) x=(x+2)&0xE end
    print(string.format("DROP pos=%d cam=%d n=%d list=%s pending=%s",pos(),rw(0x1BB8)//2,n,table.concat(l," "),table.concat(pend,",")))
  end end end, emu.callbackType.exec, 0xE3BF)
-- ring write at E2DD / E339 (new pending id): full if (C4+2)&0xE == C2
local function chk() if wraps>=1 and ((rw(0x1BC4)+2)&0xE)==rw(0x1BC2) then fulls[#fulls+1]=pos() end end
emu.addMemoryCallback(chk, emu.callbackType.exec, 0xE2DD)
emu.addMemoryCallback(chk, emu.callbackType.exec, 0xE339)
local function report()
  local function s(t) local o={} local seen={} for _,v in ipairs(t) do local k=v//16*16 if not seen[k] then seen[k]=1 o[#o+1]=k end end return table.concat(o,",") end
  print(string.format("DET seed=%s L=%d drops=%d [%s] ringfull=%d [%s] maxn=%d wraps=%d",os.getenv("SEED") or os.getenv("TRACK") or "-",rw(0x200)//32,#drops,s(drops),#fulls,s(fulls),maxn,wraps))
end
R.run(12000,function(f)
  if os.getenv("TRACK") and f>=2000 and f<2400 then emu.write(0x1F06,tonumber(os.getenv("TRACK")),mt) end
  if SEED and f>=1000 and f<1500 then w2(0x1F800,SEED&0xFFFF) w2(0x1F802,(SEED>>16)&0xFFFF) w2(0x1F804,1) w2(0x1F806,0xA55A) end
  if f>3150 then
    local p=rw(0x1ED7)
    if p<last-2000 then wraps=wraps+1 if wraps>=2 then
      local function s(t) local o={} local seen={} for _,v in ipairs(t) do local k=v//16*16 if not seen[k] then seen[k]=1 o[#o+1]=k end end return table.concat(o,",") end
      print(string.format("DET seed=%s L=%d drops=%d [%s] ringfull=%d [%s] maxn=%d",os.getenv("SEED") or os.getenv("TRACK") or "-",rw(0x200)//32,#drops,s(drops),#fulls,s(fulls),maxn))
      emu.stop(0) end end
    last=p
    local n=rw(0x1BE6) if n>maxn then maxn=n end
  end
end,report)
