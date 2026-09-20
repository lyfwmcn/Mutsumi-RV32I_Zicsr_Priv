# AGENTS.md

Pipelined RV32I + Zicsr RISC-V core (M/S/U privilege, CSR, traps) for iCESugar-Pro (ECP5). Simulation-first. Encodings/CSR/exception tables live in `docs/RV32I_Zicsr_Ref.md` (Chinese). `README.md` is a short Chinese toolchain quickstart whose progress notes are stale — trust the Makefile, not the README. Everything runs from the repo root via one Makefile. Primary working branch is `Develop` (`origin/HEAD` points at `main`).

## Reset model and build state

- `src/` is **reset-based**: every flop is `always @(posedge clk or negedge rst_n)`, with no `initial` state init and no power-on defaults. `rst_n` is an active-low async-assert port on `cpu` and every submodule.
- Sim vs board reset: `sim/tb.v` holds `rst_n = 0` for 200 ns then releases; `syn/top.v` derives `rst_n` from an 8-bit counter that releases at `0xFF` (255 clocks). Anything that depends on initial state must work under both.
- `make`, `make all`, `make sim` work end-to-end (verified); the sim prints six `.` then `OK`.
- `make timing` runs, but `tools/stage_timing.py` still keys on old CamelCase tokens (`IFStage`, `EXStage`, `M1Stage`, …) and has no EX1/EX2 split, so every net lands in `OTHER`. Fix `STAGE_TOKENS`/`STAGE_ORDER` to the snake_case names (`if_stage`, `id_stage`, `ex1_stage`, `ex2_stage`, `m1_stage`, `m2_stage`, `wb_stage`, `system_bus`, `reg_file`, `csr_file`, `privilege_mode`) before trusting its per-stage table.

## Layout

- `src/` — CPU RTL, all snake_case. Pipeline **IF → ID → EX1 → EX2 → M1 → M2 → WB**, wired in `src/cpu.v`. Submodules live inside their stage: `if_stage`→`pc_reg`,`instr_buffer_unit`; `id_stage`→`idu`; `ex1_stage`→`reg_bypass`,`csr_hazard`; `ex2_stage`→`alu`; `m1_stage`→`bu`,`csr_read`; `m2_stage`→`trap_unit`; `wb_stage` is pure combinational (reg-source mux, no clock). Top-level in `cpu.v`: `csr_file`, `privilege_mode`, `reg_file`, `trap_csr_bypass`.
- `sim/` — behavioral testbench: `system_bus.v` (4 KB byte memory, `$fread("build/sim_test.bin")`, `$write`s a byte on a store to **0xFFC**) and `tb.v`.
- `syn/` — board: `top.v` (reset counter + `cpu` + `system_bus` + activity LEDs), `top.lpf`, `system_bus.v` (true-dual-port `DP16KD` EBR lanes + UART), `uart_tx.v`. `top_bustest.v` is an untracked, CPU-less bus-liveness test that defines an alternate `top` (pick one or it collides).
- The two `system_bus` files share the module name but **not the port list** now: `syn/system_bus.v` adds `rst_n` and `uart_tx`, `sim/system_bus.v` has neither. A port change still needs both. Memory init also differs: sim `$fread`s the binary; syn `$readmemh`s `build/syn_mem0/1.hex` (kept in an `initial` so sim and EBR INIT agree).
- `filelists/sim_filelist.f` / `syn_filelist.f` — iverilog vs yosys source lists. New files must be added to the correct list or the tool won't see them.
- `tests/sim/` — sim program: `start.s` (self-checking S-mode delegation test), empty `trap.s`, commented-out `main.c`, `linker.ld`. `tests/syn/` — board program `test.s` + `linker.ld`.
- `tests/<Category>/test.s` (R, S, B, Load, J, Jalr, ArithmeticI, CSR) — standalone reference snippets, **not referenced by the Makefile**. Don't drop one into `tests/sim/` or `tests/syn/` as-is (each defines `_start`).
- `tools/` — `bin2hex.py` (bin → EBR lane hex), `stage_timing.py` (nextpnr JSON → stage table), `timing_report.py` (readable nextpnr timing/path-collapse report), `json_deal.py` (JSON pretty-printer).
- `build/` (all artifacts) and `.vscode/` are gitignored; `abc.history` is a stray untracked yosys/abc artifact at the root.

## Commands (run from repo root — paths are root-relative)

- `make` / `make all` / `make sim` — compile `tests/sim/*` + link via `tests/sim/linker.ld` → `build/sim_test.bin`, then iverilog `-f filelists/sim_filelist.f` → `build/sim` and run it. The sim reads `build/sim_test.bin` at runtime; `tb.v` dumps `build/wave.vcd`.
- `make synth` — yosys `synth_ecp5` → nextpnr-ecp5 `--freq 65` → ecppack → `build/top.bit`, **then auto-programs** by copying to the iCELink volume (must be mounted at `/run/media/$USER/iCELink`). If the new config doesn't start, replug USB to reload from SPI flash.
- `make timing` — same synth → nextpnr `--freq 25 --detailed-timing-report` → `tools/stage_timing.py` (caveat above). It does **not** pass `-noflatten`; ABC9 keeps `cpu.<stage>.<sub>` cell names in the JSON, so the names are snake_case, not the script's CamelCase tokens.
- `make clean`.
- Flags: `-march=rv32i_zicsr -mabi=ilp32 -ffreestanding`. No lint, CI, or test framework in-repo.
- **CWD matters**: `syn/system_bus.v` does `$readmemh("build/syn_mem0.hex", ...)` and `sim/system_bus.v` does `$fopen("build/sim_test.bin")`; yosys/iverilog must run from the repo root (the Makefile does).

## Bus and board

- Both bus variants fault on misaligned or out-of-`0x0–0xFFF` accesses and drop the store.
- Board serial: writes to **0xFFC–0xFFF (word 1023)** send each byte-enabled lane out `uart_tx` in lane0→lane3 order (8N1, `UART_DIV = 25e6/115200 = 217`), back-pressuring `respond_valid_data` until each byte is sent. The sim variant instead `$write`s `data[7:0]` once. There is **no 0xE00/0xF00 report mailbox**; `tests/syn/test.s` writes 0xFFC and prints `Mutsumi RV32I`.
- `syn/top.lpf`: clk **P6**, LEDs `led_r=B11 led_g=A11 led_b=A12`, `uart_tx=B9 DRIVE=4`, all `LVCMOS33` (mixed bank voltages are rejected). LEDs show bus activity (`led_r/g/b` = instr request valid / data request valid / write), not PASS/FAIL.
- The LPF `FREQUENCY PORT "clk" 25 MHZ` **overrides the Makefile's `--freq 65`** — nextpnr logs `constraining clock net 'clk' to 25.00 MHz`; the real constraint is 25 MHz.

## Microarchitecture and hazards

- Forwarding: `reg_bypass` (GPR, inside `ex1_stage`), `csr_hazard` (EX1 CSR read vs in-flight writes), `trap_csr_bypass` (top-level; M2/WB CSR bypass). Stall = `reg_wait | csr_wait | mem_wait`.
- `src/cpu.v` flush terms differ per stage and are subtle (IF also flushes on mispredict when no stall pending; ID on `(reg_wait|csr_wait)&!mem_wait`; M2 only on `trap|mem_wait`). Don't simplify blindly.
- CSR reads resolve in EX1 (`csr_rs`/`csr_out` are `ex1_*`); M2/WB writes are bypassed around in-flight ops.
- `syn/system_bus.v` deliberately keeps its address/data registers in a plain `always @(posedge clk)` block (no `rst_n`) so yosys absorbs them into EBR input registers; don't "tidy" an async reset in or place/route/BRAM inference breaks. The valid/enable registers do take `rst_n`.

## Testing pitfalls

- `sim/tb.v` is a scenario harness (drives the timer/external interrupt lines; prints regs and `mem[4092]` at ~t=15200 ns), **not a correctness oracle** for the CPU. Raise the sample time and confirm the PC parks in the intended loop with zero traps before trusting dumps.
- `tests/sim/start.s` is the real sim test (M/S exception delegation): it prints `.`/`F` per check to address 4092, then `OK`/`FAIL`. Empty `tests/sim/trap.s` and commented-out `main.c` contribute nothing, and `tests/sim/linker.ld` defines no trap handler section.
- Cheap detector for flush/taken-branch bugs: put `j loop` immediately before a store you never expect to run (sentinel); if that address becomes nonzero, a redirected fetch leaked stale state.
- **iverilog requires net declarations before use** in continuous assignments, while yosys tolerates late ones. Keep `wire`/`reg` declarations above the `assign`/instance that references them (e.g. `m1_nextpc`, the `Data8S`/`Data16S`/`Data32`/`Data8U`/`Data16U` decode wires) or synth passes while `make sim` fails elaboration.

## Toolchain gotcha

nextpnr here is the archlinuxcn `-git` build (verified: `nextpnr-git 0.11.1.r30`); pair it with `prjtrellis-db-git`. The release `prjtrellis-db` crashes `ecppack` with `row_bias`.

## Editor (optional, gitignored)

`.vscode/settings.json` enables verible-verilog-ls for cross-file module jumps and verilator lint with `-y src -y sim -y syn` (its `-y src/stubs` path does not exist).
