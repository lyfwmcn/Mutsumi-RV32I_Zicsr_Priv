CC           := riscv64-unknown-elf-gcc
LD           := riscv64-unknown-elf-ld
OBJCOPY      := riscv64-unknown-elf-objcopy
IVERILOG     := iverilog
PYTHON       := python3
YOSYS        := yosys
NEXTPNR_ECP5 := nextpnr-ecp5
ECPPACK      := ecppack


BUILD_DIR    := build


SIMBIN       := $(BUILD_DIR)/sim_test.bin
SIMELF       := $(BUILD_DIR)/sim_test.elf
SIMOBJ       := $(BUILD_DIR)/sim_start.o $(BUILD_DIR)/sim_trap.o $(BUILD_DIR)/sim_main.o
SIMLDSCRIPT  := tests/sim/linker.ld
BIN2HEX      := tools/bin2hex.py


SYNMEM0      := $(BUILD_DIR)/syn_mem0.hex
SYNMEM1      := $(BUILD_DIR)/syn_mem1.hex
SYNBIN       := $(BUILD_DIR)/syn_test.bin
SYNELF       := $(BUILD_DIR)/syn_test.elf
SYNOBJ       := $(BUILD_DIR)/syn_test.o
SYNASM       := tests/syn/test.s
SYNLDSCRIPT  := tests/syn/linker.ld


SIMFILELIST  := filelists/sim_filelist.f
SIMSRCS      := $(shell cat filelists/sim_filelist.f | grep -v '^$$')
SIM          := $(BUILD_DIR)/sim


SYNSRCS      := $(shell cat filelists/syn_filelist.f | grep -v '^$$')
SYN          := $(BUILD_DIR)/top.bit
CONFIG       := $(BUILD_DIR)/top_out.config
JSON         := $(BUILD_DIR)/top.json
LPF          := syn/top.lpf


TIMING       := $(BUILD_DIR)/timing.json
TIMCONFIG    := $(BUILD_DIR)/timing.config
TIMJSON      := $(BUILD_DIR)/timing_synth.json
STAGETIMING  := tools/stage_timing.py


.PHONY: all sim synth timing clean


all: sim | $(BUILD_DIR)


$(BUILD_DIR):
	mkdir -p $@


$(SIMBIN): $(SIMELF) | $(BUILD_DIR)
	$(OBJCOPY) -O binary $< $@

$(SIMELF): $(SIMOBJ) $(SIMLDSCRIPT) | $(BUILD_DIR)
	$(LD) -m elf32lriscv -T $(SIMLDSCRIPT) $(SIMOBJ) -o $@

$(BUILD_DIR)/sim_%.o: tests/sim/%.s | $(BUILD_DIR)
	$(CC) -c $< -o $@ -march=rv32i_zicsr -mabi=ilp32 -ffreestanding

$(BUILD_DIR)/sim_%.o: tests/sim/%.c | $(BUILD_DIR)
	$(CC) -c $< -o $@ -march=rv32i_zicsr -mabi=ilp32 -ffreestanding


sim: $(SIM) | $(BUILD_DIR)
	./$<

$(SIM): $(SIMFILELIST) $(SIMSRCS) $(SIMBIN) | $(BUILD_DIR)
	$(IVERILOG) -o $@ -f $<


synth: $(SYN) | $(BUILD_DIR)
	@set -e; D=$$(find /run/media/$$USER -maxdepth 1 -name iCELink 2>/dev/null | head -1); \
	if [ -z "$$D" ]; then echo "iCELink 盘未挂载，请先挂载后再 make prog"; exit 1; fi; \
	cp $(SYN) $$D/ && sync && echo "已复制到 $$D，固件自动烧写中…"

$(SYN): $(CONFIG) | $(BUILD_DIR)
	$(ECPPACK) --input $< --bit $@

$(CONFIG): $(JSON) $(LPF) | $(BUILD_DIR)
	$(NEXTPNR_ECP5) --25k --package CABGA256 --speed 6 --json $(JSON) --textcfg $@ --lpf $(LPF) --freq 65

$(JSON): $(SYNSRCS) $(SYNMEM0) $(SYNMEM1) | $(BUILD_DIR)
	$(YOSYS) -p "read_verilog -sv $(SYNSRCS); hierarchy -top top; synth_ecp5 -json $(JSON)"

$(SYNMEM0) $(SYNMEM1) &: $(SYNBIN) $(BIN2HEX) | $(BUILD_DIR)
	$(PYTHON) $(BIN2HEX) $< $(SYNMEM0) $(SYNMEM1)

$(SYNBIN): $(SYNELF) | $(BUILD_DIR)
	$(OBJCOPY) -O binary $< $@

$(SYNELF): $(SYNOBJ) $(SYNLDSCRIPT) | $(BUILD_DIR)
	$(LD) -m elf32lriscv -T $(SYNLDSCRIPT) $< -o $@

$(SYNOBJ): $(SYNASM) | $(BUILD_DIR)
	$(CC) -c $< -o $@ -march=rv32i_zicsr -mabi=ilp32 -ffreestanding


timing: $(TIMING) $(STAGETIMING) | $(BUILD_DIR)
	$(PYTHON) $(STAGETIMING) $<

$(TIMJSON): $(SYNSRCS) $(SYNMEM0) $(SYNMEM1) | $(BUILD_DIR)
	$(YOSYS) -p "read_verilog -sv $(SYNSRCS); hierarchy -top top; synth_ecp5 -noflatten -json $(TIMJSON)"

$(TIMING): $(TIMJSON) $(LPF) | $(BUILD_DIR)
	$(NEXTPNR_ECP5) --25k --package CABGA256 --speed 6 --json $(TIMJSON) --textcfg $(TIMCONFIG) --lpf $(LPF) --freq 25 --report $@ --detailed-timing-report


clean:
	rm -rf $(BUILD_DIR)
