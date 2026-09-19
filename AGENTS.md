# AGENTS.md

Pipelined RV32I + Zicsr RISC-V core (M/S/U privilege, CSR, traps) for iCESugar-Pro (ECP5) / iCESugar (iCE40). Simulation-first. Design reference (encodings/CSR/exception tables, Chinese) is `docs/RV32I_Zicsr_Ref.md`; `README.md` is a bare toolchain quickstart and is stale on the test layout. Everything builds and runs from the repo root via one Makefile.

## Current refactor state — read before running anything

The RTL was renamed to snake_case and all state now initializes via `initial` blocks (`src/` has **no reset port**). The synthesis side was updated; the simulation side was not:

- `filelists/syn_filelist.f` lists the real snake_case `src/*.v` + `syn/*.v`.
- `filelists/sim_filelist.f` and `sim/tb.v` still reference the old CamelCase files/modules (`src/ALU.v`, `src/CPU.v`, `SystemBus` ports `CLK/RST`, ...). **`make sim` / `make` currently fail** (`No rule to make target 'src/ALU.v'`).
- `tools/stage_timing.py` still keys on old CamelCase stage tokens (`IFStage`, `IDStage`, ...), so `make timing`'s per-stage table now lumps everything into `OTHER`.

Port the sim harness and update the stage tokens before trusting `make sim` or `make timing` stage output.

## Directory layout

- `src/` — CPU RTL, all snake_case. Pipeline is **IF → ID → EX1 → EX2 → M1 → M2 → WB**, wired in `src/cpu.v`. Submodules live inside their stage: `if_stage`→`pc_reg`,`instr_buffer_unit`; `id_stage`→`idu`; `ex1_stage`→`reg_bypass`,`csr_hazard`; `ex2_stage`→`alu`; `m1_stage`→`bu`,`csr_read`; `m2_stage`→`trap_unit`. Top-level in `cpu.v`: `csr_file`, `privilege_mode`, `reg_file`, `trap_csr_bypass`.
- `sim/` — simulation only: `SystemBus.v` (behavioral 4 KB byte memory, `$fread("build/sim_test.bin")`, prints a byte on a store to **0xFFC**) and `tb.v`.
- `syn/` — synthesis/board: `top.v`, `top.lpf`, `system_bus.v` (ECP5 EBR-lane memory + UART), `uart_tx.v`. The old `report.v` / `rst_gen.v` are gone.
- `filelists/sim_filelist.f` / `syn_filelist.f` — iverilog vs yosys source lists. New files must be added to the correct list or the tool won't see them.
- `tests/sim/` — sim program: `start.s`, `trap.s`, `main.c`, `linker.ld`. `tests/syn/` — board program: `test.s`, `linker.ld`.
- `tests/<Category>/test.s` (R, S, B, Load, J, Jalr, ArithmeticI, CSR) — standalone reference snippets, **not referenced by the Makefile**. Don't drop one into `tests/sim/` or `tests/syn/` as-is (both define `_start`).
- `tools/bin2hex.py` — `build/syn_test.bin` → `build/syn_mem0.hex` + `build/syn_mem1.hex` (EBR lane words; layout documented in the file and `syn/system_bus.v`).
- `tools/stage_timing.py` — nextpnr detailed-timing JSON → `build/stage_timing.md` + `.csv`.
- `build/` holds all artifacts and is gitignored; `.vscode/` is gitignored too.

## Commands (run from the repo root — paths are root-relative)

- `make` / `make sim` — compile `tests/sim/*` + link `tests/sim/linker.ld` → `build/sim_test.bin`, iverilog `-f filelists/sim_filelist.f` → `build/sim`. Currently broken (see refactor state). Reads `build/sim_test.bin` at runtime; `tb.v` dumps `build/wave.vcd`.
- `make synth` — yosys flattened `synth_ecp5` → nextpnr-ecp5 `--freq 65` → ecppack → `build/top.bit`, **then auto-programs** by copying to the iCELink volume (must be mounted at `/run/media/$USER/iCELink`). If the new config doesn't start, replug USB to reload from SPI flash.
- `make timing` — separate `synth_ecp5 -noflatten` → nextpnr `--freq 25 --detailed-timing-report` → `tools/stage_timing.py`. `-noflatten` is required: the default flatten/techmap erases the stage cell names the script keys on.
- `make clean`.
- Flags: `-march=rv32i_zicsr -mabi=ilp32 -ffreestanding`. No lint, CI, or test framework.
- **CWD matters**: `syn/system_bus.v` does `$readmemh("build/syn_mem0.hex", ...)` and `sim/SystemBus.v` does `$fopen("build/sim_test.bin")`, so yosys/iverilog must run from the repo root (the Makefile does).

## Bus and board

- The two bus variants have **diverged** (they used to be identical): `sim/SystemBus.v` is `module SystemBus`, CamelCase ports + `RST`, plain byte memory; `syn/system_bus.v` is `module system_bus`, lowercase ports, no reset, true-dual-port `DP16KD` EBR lanes. `sim/tb.v` wires `SystemBus`; `syn/top.v` wires `system_bus` — a port change only needs the matching variant and its top.
- Both fault on misaligned or out-of-`0x0–0xFFF` accesses and drop the store.
- Board serial output: a store to **0xFFC–0xFFF (word 1023)** sends the byte-enabled lane bytes out `uart_tx` (8N1, `UART_DIV = 25e6/115200 = 217`), back-pressuring `respond_valid_data` until sent. **There is no 0xE00/0xF00 report mailbox anymore**; `tests/syn/test.s` still writes 0xE00/0xF00, so as-is it prints nothing.
- `syn/top.lpf`: clk **P6 = 25 MHz**, LEDs `led_r=B11 led_g=A11 led_b=A12`, `uart_tx=B9 DRIVE=4`, all `LVCMOS33` (mixed bank voltages are rejected). LEDs show bus activity (`led_r/g/b` = request valid instr/data, write data), not PASS/FAIL.
- The LPF has `FREQUENCY PORT "clk" 25 MHZ`, which **overrides the Makefile's `--freq 65`** — nextpnr logs `constraining clock net 'clk' to 25.00 MHz` and the real constraint is 25 MHz.

## Microarchitecture and hazards

- Hazard/forwarding: `reg_bypass` (GPR, inside `ex1_stage`), `csr_hazard` (EX1 CSR read vs in-flight writes), `trap_csr_bypass` (top-level; M2/WB CSR bypass). Stall = `reg_wait | csr_wait | mem_wait`.
- Flush conditions differ per stage and are subtle (IF also flushes on mispredict when no stall is pending; ID on reg/csr wait without mem wait; M2 flushes only on `trap | mem_wait`). Don't simplify these blindly.
- CSR reads resolve in EX1 (`csr_rs`/`csr_out` are `ex1_*`); M2/WB writes are bypassed around in-flight ops.
- `syn/system_bus.v` deliberately keeps its address/data registers in a plain (non-reset) always block so yosys absorbs them into EBR input registers; don't "tidy" a reset in.

## Testing pitfalls

- `sim/tb.v` samples registers once at t=20000 ns (~2000 cycles) and is **not a correctness oracle**; raise the sample time and confirm the PC parks in the intended loop with zero traps before trusting dumps.
- State comes from `initial`, not a reset pin, so simulation and FPGA GSR/config must agree on init values. Trap tests must set `mtvec` (and `stvec` when delegating) and provide a handler; `tests/sim/linker.ld` defines no handler section. `tests/sim/start.s` writes `B`/`C` to 0xFFC (address 4092) from its M/S handlers.
- Cheap detector for flush/taken-branch bugs: `j loop` immediately followed by a store you never expect to run (sentinel); if that address becomes nonzero, a redirected fetch leaked stale state.

## Toolchain gotcha

nextpnr here is the archlinuxcn `-git` build; pair it with `prjtrellis-db-git`. The release `prjtrellis-db` crashes `ecppack` with `row_bias`.

## Editor (optional, gitignored)

`.vscode/settings.json` enables verible-verilog-ls for cross-file module jumps and verilator lint with `-y src -y sim -y syn`.
