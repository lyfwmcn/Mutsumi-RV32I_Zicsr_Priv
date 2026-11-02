# 综合文件表（顺序无关；空行和 # /// 注释会被过滤掉）
# ---- CPU 核 ----
src/core/core.v
src/core/idu.v
src/core/id_stage.v
src/core/ex1_stage.v
src/core/ex2_stage.v
src/core/m1_stage.v
src/core/m2_stage.v
src/core/alu.v
src/core/bu.v
src/core/reg_file.v
src/core/reg_bypass.v
src/core/csr_file.v
src/core/csr_read.v
src/core/csr_hazard.v
src/core/trap_unit.v
src/core/trap_csr_bypass.v
src/core/privilege_mode.v
src/core/if_stage.v
src/core/instr_buffer_unit.v
src/core/pc_reg.v
# ---- cache / mmu（uncore 一体化：取指 + 数据 + TLB/PWC + A/D 补位）----
src/uncore.v
src/i_cache_ram.v
src/d_cache_ram.v
# ---- 上电加载 ----
syn/boot_rom.v
syn/cpu_subsys.v
# ---- 板上外设 / 顶层 ----
syn/rst_gen.v
syn/uart_tx_unit.v
syn/sdram_ctr.v
syn/sdram_phy_ecp5.v
syn/null_device.v
syn/device.v
syn/top.v
