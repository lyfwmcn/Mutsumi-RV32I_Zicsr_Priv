# AGENTS.md

Course-style Chinese Verilog project: a pipelined RV32I + Zicsr RISC-V core (M/S/U privilege, CSR, traps/exceptions, paging) for iCESugar-Pro (ECP5) / iCESugar (iCE40). Simulation-first. **Design reference (encodings/CSR/exception tables, Chinese) lives in `docs/RV32I_Zicsr_Ref.md`**; `README.md` is only a bare toolchain quickstart and is stale on the test layout. Everything builds and runs from the repo root via one Makefile.

## Directory layout (get this right — it changed before)

- `src/` — CPU RTL: `CPU.v` plus stage/unit modules (no testbench here).
- `sim/` — simulation-only: `sim/SystemBus.v` (behavioral `reg [7:0] mem[4095:0]`) and `sim/tb.v` (dumps `build/wave.vcd`).
- `syn/` — synthesis-only board shell: `top.v`, `top.lpf`, `SystemBus.v` (ECP5 EBR lane variant), `report.v`, `rst_gen.v`, `uart_tx.v`.
- **There are two `module SystemBus` variants (`sim/SystemBus.v` vs `syn/SystemBus.v`). They must keep identical module name and port list** — CPU wires the same bus in `sim/tb.v` and `syn/top.v`. Change memory behavior in the matching variant; a port change must land in both. The sim variant loads `build/sim_test.bin` at t=0 and has an MMIO byte-out: a store to `0xFFC` does `$write("%c", ...)` (this is what `tests/sim/main.c` `putc` uses). The syn variant is `mem0`/`mem1` 18-bit EBR lanes with a `translate_off` byte mirror for simulation, and has no UART (board printing is `syn/report.v`).
- `filelists/sim_filelist.f` and `filelists/syn_filelist.f` — iverilog (sim) and yosys (syn) source lists. Both include `src/*`. `sim` adds `sim/SystemBus.v` + `sim/tb.v`; `syn` adds the `syn/*` RTL and **must not** contain any tb. New files go into the right list or the tool won't see them.
- `tests/sim/` — the simulation program: `start.s` (`_start` sets `sp`, `call main`), `main.c`, `linker.ld` (adds a 1K stack). `make sim` builds exactly these.
- `tests/syn/` — the board program: `test.s` + `linker.ld`. `make synth` builds exactly these. **The sim and board programs are now different source trees** (formerly one `tests/test.s`).
- `tests/<Category>/test.s` (R, S, B, Load, J, Jalr, ArithmeticI, CSR) are **standalone reference snippets not referenced by the Makefile**. Do not drop one into `tests/sim/` or `tests/syn/` as-is — both already define `_start`; adapt the body manually.
- `tools/bin2hex.py` — `build/syn_test.bin` → `build/syn_mem0.hex` + `build/syn_mem1.hex` (EBR lane words, 4KB zero-padded; lane layout documented in the file and `syn/SystemBus.v`).
- `tools/stage_timing.py` — parses nextpnr detailed-timing JSON into a per-pipeline-stage table.
- `build/` — all artifacts (gitignored); `.vscode/` is gitignored too.

## Commands (must run from repo root — paths are root-relative)

- `make` / `make sim` — compile `tests/sim/start.s` + `tests/sim/main.c`, link `tests/sim/linker.ld` → `build/sim_test.bin`, iverilog `-f filelists/sim_filelist.f`, run `build/sim`. Reads `build/sim_test.bin` at runtime; tb dumps `build/wave.vcd` and prints a couple regs (`x5`,`x6`) at **t=20000 ns (~2000 cycles)** then `$finish`.
- `make synth` — yosys (`syn_filelist.f`, EBR INIT from `build/syn_mem0/1.hex`) → nextpnr-ecp5 `--freq 65` → ecppack → `build/top.bit`, **then auto-programs the board** by copying to the iCELink volume (requires it mounted at `/run/media/$USER/iCELink`; errors otherwise). The board program is `tests/syn/test.s`. If the new config doesn't start, replug USB to reload from SPI flash.
- `make timing` — synthesizes a separate `build/timing_synth.json` with `synth_ecp5 -noflatten` (the bitstream `top.json` stays flattened), then nextpnr-ecp5 `--freq 25 --detailed-timing-report` → `build/timing.json`, then `tools/stage_timing.py` → `build/stage_timing.md` + `build/stage_timing.csv`. `-noflatten` is required: the default flatten/techmap erases `IDStage`/`M1Stage` cell names, so the script's stage tokens can't see those stages. Also `detailed_net_timings[].sources` are RTL `src` location strings, not cell names.
- `make clean` — removes `build/`.
- Compile flags: `-march=rv32i_zicsr -mabi=ilp32 -ffreestanding`. No test framework, lint, or CI.
- ECP5 toolchain gotcha: nextpnr here is the archlinuxcn `-git` build, so the paired package is `prjtrellis-db-git`, **not** the release `prjtrellis-db` (release db crashes ecppack with `row_bias`).

## Microarchitecture (wiring in `src/CPU.v`)

- Pipeline `IF → ID → EX → M1 → M2 → WB`; M1 issues the data-bus request, M2 consumes the response with alignment/fault checks.
- Hazard/forwarding units instantiated in `CPU.v`: `RegByPass` (GPR fwd + `RegWait`), `CSRHazard` (CSR RAW → `CSRWait`), `TrapCSRByPass`. Stalls `RegWait|CSRWait|MemWait`; flush conditions are per-stage and subtle — e.g. IF flush `ActualJump | (PredJump & !RegWait & !CSRWait & !MemWait) | Trap | Ret`, ID flush differs. Don't simplify these blindly.
- Memory: 4KB, access must be aligned and within 0x0–0xFFF; misaligned/out-of-range accesses fault and stores are dropped (both SystemBus variants enforce this). 0xE00–0xF00 are ordinary memory in sim but have report semantics on the board.

## Board observability (`syn/report.v`)

- A store to mailbox **0xF00** triggers a UART dump of the 32-word report window **0xE00–0xE7F** (8 hex + CRLF per word, then `PASS`), repeating every ~1 s. LEDs: 000 idle, 001 dumping, 111 PASS steady, blink=FAIL (timeout: mailbox never written).
- So a board program must store results to 0xE00.. and write 0xF00. **Burning a variant that never writes 0xF00 → FAIL blink and no serial** (silent-looking). `tests/syn/test.s` already does both.
- Board: ECP5 LFE5U-25F CABGA256, clk **P6 = 25 MHz**, RGB LED {A11,A12,B11}, UART **TX=B9 → iCELink USB-CDC** `/dev/ttyACM0` @115200. A11/A12/B11/B9 share an IO bank: keep them all **LVCMOS33** in `syn/top.lpf` or nextpnr rejects mixed bank voltages. CRLF is handled; bare LF makes terminals staircase. ModemManager may steal the port and eat automated captures — manual terminals usually work.

## Testing pitfalls (learned the hard way)

- `tb.v` samples **once at t=20000 ns and is not a correctness oracle**. A real bug (taken-branch redirect left stale in-flight prefetch in `InstrBufferUnit.v`; fixed) made the CPU run off into zero padding and trap-loop to `mtvec=0`; restarts rewrote registers to identical values, hiding it from the snapshot.
- Cheap detector: `j loop` immediately followed by a store you never expect to run (sentinel) — if the sentinel address is nonzero, a taken branch leaked. For loop/branch/flush changes, raise tb's sample time and confirm the PC parks in the intended loop with zero traps before trusting reg dumps.
- `mtvec` resets to 0 and `tests/sim/linker.ld` defines no handler; trap tests must both `csrw mtvec` and add a handler section to the linker script.
- `syn/SystemBus.v` mixes async-reset and non-async-reset registers deliberately: address/data registers are left un-reset so yosys can absorb them into EBR input registers. Don't "tidy" them into the async-reset block.

## Editor (optional, gitignored `.vscode/`)

- `.vscode/settings.json` enables verible-verilog-ls for cross-file module jumps (built-in Verilog features only index the open file). No `verible.filelist` needed — verible resolves modules across the workspace on its own.
