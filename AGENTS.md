# AGENTS.md

RV32I + Zicsr + Sv32 软核，Verilog/SystemVerilog，目标 Lattice ECP5（25k，CABGA256，speed 6）。
远端：`git@github.com:lyfwmcn/CPU3.git`。

**当前状态：能跑。** CPU 从固定 ROM（0~4K）直接启动，I/D cache + TLB/PWC + Sv32 分页 + 硬件补 A/D
全部工作；上板串口自检逐字节 0 错。没有 boot loader，SDRAM 最低 4K 闲置。

## 命令

- `make` / `make all` → `make synth`
- `make synth` — yosys → nextpnr-ecp5 → ecppack → `build/syn_top.bit`，然后拷到已挂载的
  iCELink 盘（`/run/media/$USER/iCELink`）自动烧写。盘没挂载会报错退出。
  **iCELink 卷烧写成功后会自动卸载** —— 下次烧写前先 `udisksctl mount -b /dev/sda`。
- `make build/syn_top.bit` — 只构建，不烧写。
- `make timing` — 生成 `build/timing.json` 详细时序报告（`--freq 45`）。
- `make clean` — `rm -rf build`。

工具链（本机都有）：`riscv64-unknown-elf-{gcc,objcopy}`、`yosys`、`nextpnr-ecp5`、`ecppack`、
`python3`、`verilator`。**没有 iverilog**，仿真统一用 `verilator --binary --timing`。

## 构建要点

- **文件表是编译的唯一依据**：`filelists/syn_filelist.f`（32 个文件，和模块一一对应）。
  空行和 `#` / `//` 注释会被过滤。新增 RTL 必须加进表里。
- 综合用 `read_verilog -sv`（接受 SystemVerilog）。
- **上电镜像烘进 bitstream**：`opencode/uart_prog.s` → `build/boot.hex`（`tools/bin2hex128.py`
  生成 256 行 × 128 位）→ `syn/boot_rom.v` 的 `$readmemh`。改程序必须重新综合才会生效。
  换程序：`make build/boot.hex BOOTSRC=opencode/xxx.s` 再 `make build/syn_top.bit`。
- **仿真必须在仓库根目录跑**（`boot_rom.v` 用 CWD 相对路径 `build/boot.hex`）。
- 所有 `src/`、`syn/`、`tests/` 的 `.v` 都带 `` `timescale ``（Verilator 的 TIMESCALEMOD 警告已清零）。

## 架构

### 模块层次

```
syn/top.v            板级顶层：PLL + rst_gen + cpu_subsys + LED
 └ syn/cpu_subsys.v  core + uncore + device（纯接线）
    ├ src/core/*.v   RV32I 流水线
    ├ src/uncore.v   取指/访存、I/D cache、TLB、PWC、页表走表、补 A/D、fence.i / sfence.vma
    │   ├ src/i_cache_ram.v
    │   └ src/d_cache_ram.v
    └ syn/device.v   存储器子系统
        ├ syn/boot_rom.v    ×2（i / d 各一份，EBR）
        ├ syn/null_device.v ×2
        ├ syn/uart_tx_unit.v
        ├ 仲裁器（d / i 各一个 pending 槽，d 优先）
        ├ syn/sdram_ctr.v
        └ syn/sdram_phy_ecp5.v
```

### 地址映射 / PMA

`src/uncore.v` 里的 `pma()` 返回 2 位：

| paddr（字地址） | 字节范围 | 值 | I 侧 | D 侧 |
|---|---|---|---|---|
| `[31:24] != 0` | ≥ 1 GB | 0 | access fault | access fault |
| `[23]` | ≥ 32 MB | 2 | access fault | 不缓存（直通） |
| `[22:10] == 0` | < 4 KB（ROM） | 3 | 可缓存 | 不缓存（直通） |
| 其余 | 4 KB ~ 32 MB | 1 | 可缓存 | 可缓存 |

```
0x0000_0000 ~ 0x0000_0FFF   固定 ROM（4KB，只读，内容 = build/boot.hex）
0x0000_1000 ~ 0x01FF_FFFF   SDRAM 32MB
0x0200_0000 ~ 0x3FFF_FFFF   Device（UART 写；读回 8 拍 0）
≥0x4000_0000                未映射
```

ROM 占住最低 4K，所以 **SDRAM 的最低 4K 不用**；写 ROM 区会被静默丢弃（走 null）。

### 从设备总线（四个从设备接口完全一致）

```
request_valid / request_we / request_be[15:0] / request_addr / request_data[127:0]
        │
        ▼
  request_busy（高到事务结束）  +  respond_valid × 8 拍 + respond_data[15:0]
```

- 读：8 拍 16 位数据（BL=8，从请求所在的 16 位字开始、行内绕回）；
- 写：没有响应，`request_busy` 落回 0 就是完成；
- **"事务结束" 统一用 `request_busy` 落回 0 判断**，没有单独的 done 信号。

地址单位：`sdram_ctr` / `null_device` / `uart_tx_unit` 是 24 位（2 字节单位）；
`boot_rom` 是 11 位（2 字节单位，4KB = 2048 字），行号 = `addr[10:3]`，行内 16 位字偏移 = `addr[2:0]`。

### 启动流程

```
rst_n 放开（PLL LOCK 后数 1024 拍）→ CPU 从 ROM 0x0 取指 → 跑 opencode/uart_prog.s
```

没有加载阶段，`boot_done` 恒 1。程序里 `li x1, 0x02000000` + `sb` 就是往 UART 发字节。

### cache / 分页

- I-cache / D-cache：各 4 路 × 64 行 × 16B = 1KB，tag 用**物理地址**；D-cache 写回（write-back）。
- `fence.i`：扫描 64 行 × 4 路写回 D 脏行 → 清 I cache（不清 D cache）。
- `sfence.vma`：同样先写回 D 脏行 → 清 I/D 的 PWC + TLB（不清 cache）。
- 两者共用 `D_FENCE → D_F_SCAN → D_F_WORK → D_F_DONE`，`D_F_DONE` 按 `d_op` 区分。
- 走表时硬件补 A/D：I 侧需要补 A 时委托 D 侧做读-改-写（`D_AD_I_*`），用 `d_ireturn` 记住回来该走 fence 还是 idle。
- `D_JUDGE2` 的 `2'h2/2'h3`（不缓存）走 `D_RWT_*`：一次读 16 字节、返回 `{beat1, beat0}`。

### SDRAM 仲裁（在 device 里，不在 sdram_ctr）

- d / i 各一个 pending 槽，请求是**单拍脉冲**，所以槽位"来者不拒"地锁存；
- `d_cache_request_busy` / `i_cache_request_busy` 用**槽位寄存器**（不能组合依赖 `request_valid`，
  否则和 uncore 的 `if (!busy) 发请求` 形成组合环）；
- 同一时刻只有一笔事务在 `sdram_ctr` 上，8 拍响应按 `cur` 送回对应口；d 优先；
- `sdram_ctr` 是单请求口，内部 `pending_*` 锁存后全程只用寄存器。

## 板级事实（iCESugar Pro，LFE5U-25F）

- **RGB LED 是高有效**：`led_r`=B11、`led_g`=A11、`led_b`=A12，驱动 1 点亮。
  LiteX 里叫 `user_led_n` 是**误导**，不要取反。当前接法：`led_r = boot_done`（恒亮）、
  `led_g/dbg_cpu` 和 `led_b/dbg_uart` 按设备写次数翻转。
- 所有 I/O 3.3 V（`LVCMOS33`）。输入时钟 25 MHz 在 `P6`，复位键 `L14`。
- **PLL**：`CLKI_DIV=1, CLKFB_DIV=2, CLKOP_DIV=12, CLKOP_CPHASE=5, CLKOS_DIV=12, CLKOS_CPHASE=11`
  → `CLKOP` = 50 MHz（逻辑）、`CLKOS` = 50 MHz/180° → `ODDRX1F` → `sdram_clk`。
  **相位必须 180°**（LiteX 官方 target 就是 180，90° 实测程序不跑）。
  改频率要同步改：PLL、`cpu_subsys` 的 `SYS_HZ`（UART 分频）、`sdram_ctr` 的
  `tFresh/tRP/tRCD`、`opencode/tb/tb_boot.v` 的 `BIT`。
- **SDRAM**：IS42S16160B，32 MB（4 bank × 8192 行 × 512 列 × 16 位）。
  BL=8、CAS=2（模式寄存器 `10'b0000100011`）、每次访问 auto-precharge（A10=1）；
  init = PRECHARGE-ALL → 2× AUTO-REFRESH → LOAD-MODE-REGISTER；之后每 ≤7.8 µs 刷新。
  50 MHz 下 `tRP=tRCD=2`、`tRFC=4`、`tMRD=2`、`tFresh=385`（25 MHz 下 `tRP=tRCD=1`、`tFresh=192`）。
- **SDRAM PHY（PIC/IOLOGIC）**：`syn/sdram_phy_ecp5.v` 用 `OFS1P3BX/OFS1P3DX`、`IFS1P3BX`、`BB`
  把 SDRAM 寄存器放进 I/O 单元。**所有输出晚 1 拍、读回数据再晚 1 拍**，所以 `sdram_ctr` 的
  `tCL` 必须是 **2**（0/1/3 都挂）。
- **测试台必须经 PHY 接 SDRAM 模型**，否则读回数据整体错一拍（现象像取指全 0）。
  `tests/tb/sdram_model.v` 已按上板实测校准（读数据"命令后第 1 拍"+ 半周期 tAC），别再单独调。
- **UART**：FPGA TX=B9、RX=A9 接板上 iCELink，主机侧是 USB CDC ACM `/dev/ttyACM0`，115200 8N1。

## 测试

仿真全部用 verilator，`--binary --timing`。常用命令（在仓库根目录）：

```bash
# uncore 单测
verilator --binary --timing -Wno-lint -Wno-fatal -Wno-WIDTH -Wno-UNUSED -Wno-UNDRIVEN \
  -Wno-PINMISSING -j 4 -y src --Mdir /tmp/r1 --top-module tb_uncore \
  opencode/tb/tb_uncore.v src/uncore.v -o sim && /tmp/r1/sim

# SoC 整链（要带 SDRAM 模型 + ECP5 原语模型 + 文件表）
verilator --binary --timing -Wno-lint -Wno-fatal -Wno-WIDTH -Wno-UNUSED -Wno-UNDRIVEN \
  -Wno-PINMISSING -j 8 -y src -f /tmp/files.f opencode/tb/tb_boot.v \
  tests/tb/sdram_model.v tests/tb/ecp5_prim_sim.v --Mdir /tmp/r2 --top-module tb_boot -o sim
```

`/tmp/files.f` 就是 `filelists/syn_filelist.f` 去掉注释（`grep -vE '^[[:space:]]*($|#)'`）。

| 测试台 | 内容 | 结果 |
|---|---|---|
| `opencode/tb/tb_uncore.v` | uncore 功能（bare/分页/uncached/fence/ROM 区） | 34/34 |
| `opencode/tb/tb_fence_ad.v` | fence 与 I 侧补 A 撞车的时序扫描（48 组 delay） | 48/48，命中分支 3 次 |
| `opencode/tb/tb_boot.v` | SoC 整链（core+uncore+device+sdram_ctr+PHY+模型） | 5/5，204 字节 0 错 |
| `tests/tb/tb_device.v` | device：ROM 路由 / SDRAM 读写 / **d-i 同拍仲裁** / UART 帧 / null | 15/15 |
| `tests/tb/tb_null.v` | null_device 单测 | 11/11 |
| `tests/tb/tb_uart.v` | uart_tx_unit 单测（8 拍读 0、写发首字节、busy） | 39/39 |
| `opencode/tb/tb_sdram_phy.v` | sdram_ctr + PHY + 模型 | 17/17 |
| `opencode/tb/tb_rate.v` | I 侧连取节奏 | 24 条 890 ns（38.7 ns/条） |
| `opencode/tb/tb_lb.v` | 串行 64 次 lbu | bad=0 |

### 上板测试

```bash
# 1) 构建 + 烧写
make build/syn_top.bit
udisksctl mount -b /dev/sda && cp build/syn_top.bit /run/media/$USER/iCELink/ && sync

# 2) 抓串口自检（10 轮 x 12 行 x 16 字节，和 build/boot.bin 逐字节比）
python3 tools/uart_check.py -n 10 -t 30
```

`tools/uart_check.py` 会把两类问题分开统计：**数据错字节**（真问题）和
**链接丢字节**（iCELink 的 USB 缓冲溢出，固件会往流里插 `<iCELink:Overflow>`，不是 FPGA 的问题）。

- **波特率必须显式设置**：CDC ACM 会把 line coding 发给 iCELink，继承 tty 原有设置（可能被
  别的会话改成 9600）会解出乱码。脚本里已写死 `B115200`。
- **必须关掉 IXON/XOFF**：镜像里有 `0x13`/`0x11`，主机开着软件流控会静默丢字节。
- 上板实测：连续 10 次 × 10 轮，9 次全对、1 次 1 个字节异常（约 1/12000，iCELink CDC 偶发）。
- `opencode/sdram_test.s`：把 ROM 拷到 SDRAM 0x10000、`fence.i`、跳过去跑，每轮扫 64 行
  （整个 D-cache），压 I/D 同时访问 SDRAM 的仲裁路径。实测 10 s / 166 轮全 'P'。

## 当前结果

| 项 | 值 |
|---|---|
| Fmax（seed 7，`--freq 50`，布线后） | **59.32 MHz** |
| LUT4 | 17948 |
| TRELLIS_FF | 5972 |
| DP16KD | 40 / 56（i-cache 16 + d-cache 16 + ROM 4×2） |
| DPR16X4 | 488 |

nextpnr 日志里有**两个** `Max frequency`：第一个是布局后估计（偏低），**最后一个（布线后）才是真值**。

## 已知问题 / 后续

- **没有 PMP**：`src/core/csr_file.v` 里没有 `pmpcfg*`/`pmpaddr*`（`docs/RV32I_Zicsr_Ref.md`
  里写了编码规则但没实现）。S/U 模式只能靠 Sv32 的 PTE 权限隔离，M 模式固件保护不了自己。
- **PMA 只有 2 位**：没有"不可缓存窗口"，DMA/帧缓冲会和 cache 冲突；也没有 W/X/atomic 属性。
- **没有 A 扩展**（AMO / LR-SC）。
- **ROM 只有 4 KB**：EBR 还剩 16 个 DP16KD（≈36 KB），再大就得走 SPI flash 加载。
- **运行中 PLL 失锁不会复位**：`rst_gen` 的 `always` 只在 `!rst_n` 时工作。
- `opencode/tb/` 里 `runner.py` / `run_unit.py` / `arb_build/` 是早期批量实验的归档，引用的是
  已删除的 `cache.v` / `mmu.v`，跑不起来，仅作参考。

## 约定

- 注释和文档用**中文**，和现有风格一致。
- Verible lint 在 `.vscode/settings.json` 里**故意关掉**了这些规则：`line-length`、
  `unpacked-dimensions-range-ordering`、`explicit-parameter-storage-type`、`always-comb`、
  `parameter-name-style`。不要"修"它们。
- Verilator 常用开关：`-Wno-lint -Wno-fatal -Wno-WIDTH -Wno-UNUSED -Wno-UNDRIVEN -Wno-PINMISSING`。
  但**改完 RTL 建议再跑一次不带 `-Wno-UNDRIVEN` 的 lint** —— 之前有个隐式网络 bug
  （`rom_data_a` 拼错成没声明的名字）就是被 `-Wno-UNDRIVEN` 吞掉的。

## Reference

- `docs/RV32I_Zicsr_Ref.md` — 本地 ISA / CSR / 异常 / MMU 参考（中文），实现 decode 或 CSR 前先查。
