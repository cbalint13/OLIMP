
CROSS=riscv64-unknown-elf-
CFLAGS=-g -Os -march=rv32im -mabi=ilp32


all: out/icebreaker.json out/icebreaker.bin out/icebreaker_fw.bin

sim: icesim

flash: iceprog

##
## Synthesis
##

out/icebreaker.json: rtl/icebreaker.v rtl/spimemio.v rtl/simpleuart.v rtl/icesoc.v rtl/picorv32.v rtl/olimp.v rtl/memory.v
	mkdir -p log out
	yosys -ql log/icebreaker-syn.log -p 'synth_ice40 -abc9 -device u -top icebreaker -json out/icebreaker.json' $^
	cat log/icebreaker-syn.log | sed -n '/statistics/,/CHECK/p'

out/icebreaker.asc: out/icebreaker.json
	nextpnr-ice40 --freq 40 -l log/icebreaker-pnr.log --pre-pack brd/clocks.py --up5k  --package sg48 --asc out/icebreaker.asc --pcf brd/icebreaker.pcf --json out/icebreaker.json
	cat log/icebreaker-pnr.log | sed -n '/Device utilisation/,/Placed/p'

out/icebreaker.bin: out/icebreaker.asc
	icetime -d up5k -c 20 -mtr out/icebreaker.rpt out/icebreaker.asc
	icepack out/icebreaker.asc out/icebreaker.bin

##
## Simulation
##

out/icebreaker_tb.vvp: sim/icebreaker_tb.v rtl/icebreaker.v rtl/spimemio.v rtl/simpleuart.v rtl/icesoc.v rtl/picorv32.v rtl/olimp.v rtl/memory.v sim/spiflash.v sim/clkdiv.v
	mkdir -p log out
	iverilog -s testbench -o $@ $^ `yosys-config --datdir/ice40/cells_sim.v`

icesim: out/icebreaker_tb.vvp out/icebreaker_fw.hex
	vvp -N $< +firmware=out/icebreaker_fw.hex

##
## Flash
##

iceprog: out/icebreaker.bin out/icebreaker_fw.bin
	iceprog out/icebreaker.bin
	iceprog -o 1M out/icebreaker_fw.bin

iceprog_fw: icebreaker_fw.bin
	iceprog -o 1M out/icebreaker_fw.bin

##
## Firmware
##

brd/icebreaker_sections.lds: src/sections.lds
	$(CROSS)cpp -P -DICEBREAKER -o $@ $^

out/icebreaker_fw.elf: brd/icebreaker_sections.lds src/start.s src/firmware.c src/rv32-custom.h
	$(CROSS)gcc $(CFLAGS) -DICEBREAKER -Wl,-Bstatic,-T,brd/icebreaker_sections.lds,--strip-debug -ffreestanding -nostdlib -o out/icebreaker_fw.elf src/start.s src/firmware.c
	$(CROSS)size --format berkley out/icebreaker_fw.elf

out/icebreaker_fw.hex: out/icebreaker_fw.elf
	$(CROSS)objcopy -O verilog out/icebreaker_fw.elf out/icebreaker_fw.hex

out/icebreaker_fw.bin: out/icebreaker_fw.elf
	$(CROSS)objcopy -O binary out/icebreaker_fw.elf out/icebreaker_fw.bin

# ---- Clean ----

clean:
	rm -rf out log
	rm -f testbench.vcd

.PHONY: iceprog iceprog_fw icesim
