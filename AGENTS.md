# AGENTS.md

Pipelined RV32I + Zicsr RISC-V core (M/S/U privilege, CSR, traps) for iCESugar-Pro (ECP5). Simulation-first. Encodings/CSR/exception tables live in `docs/RV32I_Zicsr_Ref.md` (Chinese). `README.md` is a bare Chinese toolchain quickstart and its "test layout" prose is stale — trust the Makefile, not the README. Everything runs from the repo root via one Makefile. Primary working branch is `Develop` (`origin/HEAD` points at `main`).

## Read this before running anything

The RTL was renamed to snake_case and all state now initializes via `initial` blocks (`src/` has **no reset port**). The synthesis side was updated; the simulation side was not:

- `filelists/syn_filelist.f` lists the real snake_case `src/*.v` + `syn/*.v`.
- `filelists/sim_filelist.f` and `sim/tb.v` still reference the old CamelCase files/modules (`src/ALU.v`, `src/CPU.v`, `SystemBus` top with `CLK/RST`/`RST`). **`make`, `make all`, and `make sim` currently fail** with `No rule to make target 'src/ALU.v'`. Verified: `make -n sim` errors immediately.
- `tools/stage_timing.py` still keys on CamelCase stage tokens (`IFStage`, `IDStage`, ...), so `make timing`'s per-stage table lumps everything into `OTHER` even though it runs.

Port the sim harness (rename entries/ports to snake_case, drop reset) and update the stage tokens before trusting `make sim` or `make timing` stage output.

## Layout

- `src/` — CPU RTL, all snake_case. Pipeline **IF → ID → EX1 → EX2 → M1 → M2 → WB**, wired in `src/cpu.v`. Submodules live inside their stage: `if_stage`→`pc_reg`,`instr_buffer_unit`; `id_stage`→`idu`; `ex1_stage`→`reg_bypass`,`csr_hazard`; `ex2_stage`→`alu`; `m1_stage`→`bu`,`csr_read`; `m2_stage`→`trap_unit`. Top-level in `cpu.v`: `csr_file`, `privilege_mode`, `reg_file`, `trap_csr_bypass`.
- `sim/` — simulation only: `SystemBus.v` (CamelCase module, `CLK/RST` ports, behavioral 4 KB byte memory, `$fread("build/sim_test.bin")`, prints a byte on a store to **0xFFC**) and `tb.v`.
- `syn/` — board: `top.v` (wires `cpu` + `system_bus`), `top.lpf`, `system_bus.v` (lowercase module, no reset, true-dual-port `DP16KD` EBR lanes + UART), `uart_tx.v`. The two bus variants have **diverged**: change one and you must change its matching top.
- `filelists/sim_filelist.f` / `syn_filelist.f` — iverilog vs yosys source lists. New files must be added to the correct list or the tool won't see them.
- `tests/sim/` — sim program: `start.s`, `trap.s` (empty), `main.c`, `linker.ld`. `tests/syn/` — board program: `test.s`, `linker.ld`.
- `tests/<Category>/test.s` (R, S, B, Load, J, Jalr, ArithmeticI, CSR) — standalone reference snippets, **not referenced by the Makefile**. Don't drop one into `tests/sim/` or `tests/syn/` as-is (both define `_start`).
- `tools/bin2hex.py` — `build/syn_test.bin` → `build/syn_mem0.hex` + `build/syn_mem1.hex` (EBR lane words, layout in file header + `syn/system_bus.v`).
- `tools/stage_timing.py` — nextpnr detailed-timing JSON → `build/stage_timing.md` + `.csv`.
- `build/` (all artifacts) and `.vscode/` are gitignored.

## Commands (run from repo root — paths are root-relative)

- `make` / `make sim` — compile `tests/sim/*` + link via `tests/sim/linker.ld` → `build/sim_test.bin`, then iverilog `-f filelists/sim_filelist.f` → `build/sim`. Currently broken (above). The sim reads `build/sim_test.bin` at runtime; `tb.v` dumps `build/wave.vcd`.
- `make synth` — yosys flattened `synth_ecp5` → nextpnr-ecp5 `--freq 65` → ecppack → `build/top.bit`, **then auto-programs** by copying to the iCELink volume (must be mounted at `/run/media/$USER/iCELink`). If the new config doesn't start, replug USB to reload from SPI flash.
- `make timing` — separate `synth_ecp5 -noflatten` → nextpnr `--freq 25 --detailed-timing-report` → `tools/stage_timing.py`. `-noflatten` is required: the default flatten/techmap erases the stage cell names the script keys on.
- `make clean`.
- Flags: `-march=rv32i_zicsr -mabi=ilp32 -ffreestanding`. No lint, CI, or test framework in-repo.
- **CWD matters**: `syn/system_bus.v` does `$readmemh("build/syn_mem0.hex", ...)` and `sim/SystemBus.v` does `$fopen("build/sim_test.bin")`; yosys/iverilog must run from the repo root (the Makefile does).

## Bus and board

- Both bus variants fault on misaligned or out-of-`0x0–0xFFF` accesses and drop the store.
- Board serial: a store to **0xFFC–0xFFF (word 1023)** sends each byte-enabled lane byte out `uart_tx` (8N1, `UART_DIV = 25e6/115200 = 217`), back-pressuring `respond_valid_data` until sent. The sim variant instead `$write`s `data[7:0]` once. **There is no 0xE00/0xF00 report mailbox anymore**; `tests/syn/test.s` still writes 0xE00/0xF00, so as-is it prints nothing.
- `syn/top.lpf`: clk **P6 = 25 MHz**, LEDs `led_r=B11 led_g=A11 led_b=A12`, `uart_tx=B9 DRIVE=4`, all `LVCMOS33` (mixed bank voltages are rejected). LEDs show bus activity (`led_r/g/b` = instr request valid / data request valid / write), not PASS/FAIL.
- The LPF `FREQUENCY PORT "clk" 25 MHZ` **overrides the Makefile's `--freq 65`** — nextpnr logs `constraining clock net 'clk' to 25.00 MHz`; the real constraint is 25 MHz.

## Microarchitecture and hazards

- Forwarding: `reg_bypass` (GPR, inside `ex1_stage`), `csr_hazard` (EX1 CSR read vs in-flight writes), `trap_csr_bypass` (top-level; M2/WB CSR bypass). Stall = `reg_wait | csr_wait | mem_wait`.
- `src/cpu.v` flush terms differ per stage and are subtle (IF also flushes on mispredict when no stall pending; ID on `(reg_wait|csr_wait)&!mem_wait`; M2 only on `trap|mem_wait`). Don't simplify blindly.
- CSR reads resolve in EX1 (`csr_rs`/`csr_out` are `ex1_*`); M2/WB writes are bypassed around in-flight ops.
- `syn/system_bus.v` deliberately keeps its address/data registers in a plain (non-reset) always block so yosys absorbs them into EBR input registers; don't "tidy" a reset in.

## Testing pitfalls

- `sim/tb.v` samples a few registers once at t=20000 ns (~2000 cycles) and is **not a correctness oracle**; raise the sample time and confirm the PC parks in the intended loop with zero traps before trusting dumps.
- State comes from `initial`, not a reset pin, so simulation and FPGA GSR/config must agree on init values. Trap tests must set `mtvec` (and `stvec` when delegating) and provide a handler; `tests/sim/linker.ld` defines no handler section. `tests/sim/start.s` writes `B`/`C` to 0xFFC (address 4092) from its M/S handlers.
- Cheap detector for flush/taken-branch bugs: put `j loop` immediately before a store you never expect to run (sentinel); if that address becomes nonzero, a redirected fetch leaked stale state.

## Toolchain gotcha

nextpnr here is the archlinuxcn `-git` build (verified: `nextpnr-git 0.11.1.r30`); pair it with `prjtrellis-db-git`. The release `prjtrellis-db` crashes `ecppack` with `row_bias`.

## Editor (optional, gitignored)

`.vscode/settings.json` enables verible-verilog-ls for cross-file module jumps and verilator lint with `-y src -y sim -y syn` (its `-y src/stubs` path does not exist).
