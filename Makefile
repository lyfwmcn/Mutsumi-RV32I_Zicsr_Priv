PYTHON       := python3

BUILD_DIR    := build

# ---------------- 上电程序镜像（烘进 bit 流，CPU 直接从 ROM 0~4K 执行）----------------
BOOTSRC      := opencode/uart_prog.s
BOOTELF      := $(BUILD_DIR)/boot.elf
BOOTBIN      := $(BUILD_DIR)/boot.bin
BOOTHEX      := $(BUILD_DIR)/boot.hex
BOOT_LINES   := 256

# ---------------- 综合 ----------------
SYNFILELIST  := filelists/syn_filelist.f
SYNSRCS      := $(shell grep -vE '^[[:space:]]*($$|#|//)' $(SYNFILELIST))
SYNLPF       := syn/top.lpf
SYNJSON      := $(BUILD_DIR)/syn_top.json
SYNCONFIG    := $(BUILD_DIR)/syn_top_out.config
SYNBIT       := $(BUILD_DIR)/syn_top.bit

# ---------------- 时序报告 ----------------
TIMJSON      := $(BUILD_DIR)/timing_synth.json
TIMCONFIG    := $(BUILD_DIR)/timing.config
TIMTIMING    := $(BUILD_DIR)/timing.json

.PHONY: all synth timing clean

all: synth


$(BUILD_DIR):
	mkdir -p $@


# ---------------- 上电程序镜像 ----------------
$(BOOTELF): $(BOOTSRC) | $(BUILD_DIR)
	riscv64-unknown-elf-gcc -march=rv32i_zicsr_zifencei -mabi=ilp32 -nostdlib -nostartfiles -Ttext=0 -o $@ $<

$(BOOTBIN): $(BOOTELF)
	riscv64-unknown-elf-objcopy -O binary $< $@

$(BOOTHEX): $(BOOTBIN) tools/bin2hex128.py
	$(PYTHON) tools/bin2hex128.py $(BOOTBIN) $@ $(BOOT_LINES)


# ---------------- 综合 / 布线 / 打包 ----------------
$(SYNJSON): $(SYNSRCS) $(SYNFILELIST) $(BOOTHEX) | $(BUILD_DIR)
	yosys -p "read_verilog -sv $(SYNSRCS); hierarchy -top top; synth_ecp5 -json $(SYNJSON)"
	rm -f abc.history

$(SYNCONFIG): $(SYNJSON) $(SYNLPF)
	# 50 MHz 下实测 Fmax 约 54~57 MHz（随版本略有波动），seed 7 一般最好
	nextpnr-ecp5 --25k --package CABGA256 --speed 6 --json $(SYNJSON) --textcfg $@ --lpf $(SYNLPF) --freq 50 --seed 7 --timing-allow-fail

$(SYNBIT): $(SYNCONFIG)
	ecppack --input $< --bit $@


# 综合 + 布线 + 打包，然后把 bit 流拷到 iCELink 盘（自动烧写）
synth: $(SYNBIT)
	@set -e; D=$$(find /run/media/$$USER -maxdepth 1 -name iCELink 2>/dev/null | head -1); \
	if [ -z "$$D" ]; then echo "iCELink 盘未挂载，请先挂载后再 make synth"; exit 1; fi; \
	cp $(SYNBIT) $$D/ && sync && echo "已复制到 $$D，固件自动烧写中…"


# ---------------- 时序报告 ----------------
$(TIMJSON): $(SYNSRCS) $(SYNFILELIST) $(BOOTHEX) | $(BUILD_DIR)
	yosys -p "read_verilog -sv $(SYNSRCS); hierarchy -top top; synth_ecp5 -json $@"

$(TIMTIMING) $(TIMCONFIG) &: $(TIMJSON) $(SYNLPF)
	nextpnr-ecp5 --25k --package CABGA256 --speed 6 --json $(TIMJSON) --textcfg $(TIMCONFIG) --lpf $(SYNLPF) --freq 45 --report $(TIMTIMING) --detailed-timing-report

timing: $(TIMTIMING)


clean:
	rm -rf $(BUILD_DIR)
