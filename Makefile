# Rebuild the disassembly from ROM + runtime trace + WRAM image.
disasm: disasm/top_gear.asm
disasm/top_gear.asm: tools/disasm.py disasm/names.txt out/trace_main.txt out/wram_3300.bin
	python3 -I tools/disasm.py "Top Gear (USA).sfc" $@ --seeds out/trace_main.txt --wram out/wram_3300.bin --names disasm/names.txt
# Re-record the trace / WRAM dump (headless Mesen, ~1 min each)
out/trace_main.txt:
	tools/mesen.sh scripts/trace.lua
out/wram_3300.bin:
	tools/mesen.sh scripts/dumpram.lua
