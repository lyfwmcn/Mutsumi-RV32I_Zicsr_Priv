# core
src/core/instr_buffer_unit.v
src/core/pc_reg.v
src/core/if_stage.v

src/core/idu.v
src/core/id_stage.v

src/core/csr_hazard.v
src/core/reg_bypass.v
src/core/ex1_stage.v

src/core/alu.v
src/core/ex2_stage.v

src/core/bu.v
src/core/csr_read.v
src/core/m1_stage.v

src/core/trap_unit.v
src/core/m2_stage.v

src/core/csr_file.v
src/core/privilege_mode.v
src/core/reg_file.v
src/core/trap_csr_bypass.v
src/core/core.v

# uncore
src/d_cache_ram.v
src/i_cache_ram.v
src/uncore.v

# device
syn/boot_rom.v
syn/null_device.v
syn/sdram_ctr.v
syn/uart_tx_unit.v
syn/device.v
syn/cpu_subsys.v

# top
syn/rst_gen.v
syn/top.v
