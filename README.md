# Mutsumi-RV32I_Zicsr_Priv

面向 Lattice ECP5（iCESugar Pro，LFE5U-25F）的 32 位 RISC-V 软核，使用
Verilog / SystemVerilog 编写。核实现了 **RV32I + Zicsr + Zifencei + 特权级 + Sv32 分页**，
上电后直接从片内 ROM 启动，不依赖 boot loader。

## 功能概览

### 处理器核

- RV32I 指令集（`misa` = `0x40000100`，仅 I 扩展，IALIGN=32）
- 流水线结构：IF / ID / EX1 / EX2 / M1 / M2
- 特权级：M / S / U，支持 `mret` / `sret` / `wfi`
- CSR：`mstatus`/`sstatus`、`mie`/`sie`、`mtvec`/`stvec`、`mcause`/`scause`、
  `mepc`/`sepc`、`mtval`/`stval`、`medeleg`、`mideleg`、`mip`/`sip`、
  `mscratch`/`sscratch`、`satp`、`misa`、`mhartid`、`mcycle`/`minstret` 及高 32 位
- 异常：指令/数据非对齐、取指/访存 access fault、非法指令、断点、三种
  `ecall`、取指/读/写 page fault；按固定优先级选出，依据 `medeleg` 决定进 M 还是 S
- 中断：`mip & mie` 参与仲裁，按 `mideleg` 和当前特权级分发，支持 M/S 中断入口；
  当前板级未接外部中断源（`external_*` / `timer_*` 输入为 0）
- 没有 M 扩展、A 扩展、浮点、压缩指令和 PMP

### 存储子系统（`src/uncore.v`）

- Sv32 两级页表，支持 4 KiB 页和 4 MiB 超级页
- TLB + PWC（页表遍历缓存）
- 硬件补 A/D：走表时自动置 Accessed / Dirty 并写回页表
- 权限检查：R/W/X/U、SUM、MXR，非叶 PTE 保留位检查
- I-cache / D-cache 各 4 路 × 64 行 × 16 B = 1 KiB，tag 使用物理地址
- D-cache 写回（write-back）；`fence.i` 写回脏行并清 I-cache；
  `sfence.vma` 写回脏行并清 PWC/TLB
- 取指与数据分离的 cache 端口，D 侧优先的 SDRAM 仲裁

### 板级外设（`syn/`）

- 25 MHz 输入 → PLL → 50 MHz 逻辑时钟；SDRAM 时钟经 `ODDRX1F` 移相 180°
- IS42S16160B SDRAM：32 MB，BL=8、CAS=2、auto-precharge，自动初始化与刷新
- SDRAM PHY 使用 ECP5 的 PIC/IOLOGIC 原语
- 4 KiB 固定 ROM，上电镜像通过 `$readmemh` 烘进 bitstream
- UART TX 115200 8N1（FPGA TX=B9，经 iCELink CDC 到 `/dev/ttyACM0`）
- RGB LED 高有效：`led_r` = 启动完成（常亮），`led_g` / `led_b` = 设备写次数指示
  （当前两者同源，程序每写一次设备区翻转）

## 内存映射

| 地址范围 | 内容 | 说明 |
|---|---|---|
| `0x0000_0000 ~ 0x0000_0FFF` | 固定 ROM（4 KiB） | 只读，上电程序镜像 |
| `0x0000_1000 ~ 0x01FF_FFFF` | SDRAM（32 MB） | 最低 4 KiB 被 ROM 占用 |
| `0x0200_0000 ~ 0x3FFF_FFFF` | Device | UART 写；读回 0 |
| `≥ 0x4000_0000` | 未映射 | access fault |

## 目录结构

```
src/core/        RV32I 流水线、CSR、异常/中断、特权级
src/uncore.v     取指/访存、I/D cache、TLB/PWC、页表走表、补 A/D、fence
syn/top.v        板级顶层（PLL + 复位 + CPU 子系统 + LED）
syn/cpu_subsys.v core + uncore + device 接线
syn/device.v     存储器路由、SDRAM 仲裁、ROM、UART、null device
syn/sdram_*.v    SDRAM 控制器与 ECP5 PHY
tests/boot_rom/  写入 boot ROM 的上电程序
tests/tb/        标准测试台
opencode/        定向测试程序与测试台
tools/           镜像转换与串口校验脚本
docs/            本地 ISA / CSR / 异常 / MMU 参考
```

`filelists/syn_filelist.f` 是综合的唯一文件表，新增 RTL 必须加进去。

## 工具链

- x86_64 Linux
- `make`、`python3`
- `riscv64-unknown-elf-gcc` / `objcopy`
- `yosys`、`nextpnr-ecp5`、`ecppack`
- `verilator`（仿真统一使用 `verilator --binary --timing`，项目不再使用 iverilog）

## 构建与烧写

```bash
make                 # 等价于 make synth
make synth           # yosys → nextpnr → ecppack，并复制到 iCELink 盘自动烧写
make build/syn_top.bit   # 只构建，不烧写
make timing          # 生成 build/timing.json 详细时序报告
make clean           # 删除 build/
```

`make synth` 需要 iCELink 盘已挂载到 `/run/media/$USER/iCELink`，否则报错退出。
烧写成功后该盘会自动卸载，下次烧写前先执行：

```bash
udisksctl mount -b /dev/sda
```

### 更换上电程序

上电镜像由 `tests/boot_rom/uart_prog.s` 编译而来，生成 `build/boot.hex` 后由
`syn/boot_rom.v` 的 `$readmemh` 读入。修改程序后必须重新综合才会生效：

```bash
make build/boot.hex BOOTSRC=opencode/sdram_test.s
make build/syn_top.bit
```

## 上板自检

当前镜像会循环回读 ROM 中的程序区并经 UART 发出，主机侧与 `build/boot.bin`
逐字节比较：

```bash
python3 tools/uart_check.py -n 10 -t 30
```

脚本固定使用 `B115200` 并关闭 IXON/XOFF。统计会区分“数据错字节”和
“iCELink USB 缓冲溢出导致的链接丢字节”。实测连续 10 次 × 10 轮，
约 1/12000 字节会出现 iCELink CDC 偶发异常。

## 仿真与测试

仿真必须在仓库根目录运行（`boot_rom.v` 使用相对路径 `build/boot.hex`）。

```bash
# uncore 单元测试
verilator --binary --timing -Wno-lint -Wno-fatal -Wno-WIDTH -Wno-UNUSED -Wno-UNDRIVEN \
  -Wno-PINMISSING -j 4 -y src --Mdir /tmp/r1 --top-module tb_uncore \
  opencode/tb/tb_uncore.v src/uncore.v -o sim && /tmp/r1/sim

# SoC 整链测试（core + uncore + device + SDRAM 控制器/PHY/模型）
verilator --binary --timing -Wno-lint -Wno-fatal -Wno-WIDTH -Wno-UNUSED -Wno-UNDRIVEN \
  -Wno-PINMISSING -j 8 -y src -f /tmp/files.f opencode/tb/tb_boot.v \
  tests/tb/sdram_model.v tests/tb/ecp5_prim_sim.v --Mdir /tmp/r2 --top-module tb_boot -o sim
```

其中 `/tmp/files.f` 是去掉注释后的 `filelists/syn_filelist.f`：

```bash
grep -vE '^[[:space:]]*($|#|//)' filelists/syn_filelist.f > /tmp/files.f
```

| 测试台 | 覆盖内容 | 结果 |
|---|---|---|
| `opencode/tb/tb_uncore.v` | uncore：bare/分页/uncached/fence/ROM 区 | 34/34 |
| `opencode/tb/tb_fence_ad.v` | fence 与 I 侧补 A 并发（48 组时序） | 48/48 |
| `opencode/tb/tb_boot.v` | SoC 整链，含 SDRAM 模型与 ECP5 原语 | 5/5，204 字节 0 错 |
| `tests/tb/tb_device.v` | ROM 路由 / SDRAM 读写 / D-I 同拍仲裁 / UART / null | 15/15 |
| `tests/tb/tb_null.v` | null_device | 11/11 |
| `tests/tb/tb_uart.v` | uart_tx_unit | 39/39 |
| `opencode/tb/tb_sdram_phy.v` | SDRAM 控制器 + PHY + 模型 | 17/17 |
| `opencode/tb/tb_rate.v` | I 侧连续取指节奏 | 24 条 890 ns |
| `opencode/tb/tb_lb.v` | 串行 64 次 `lbu` | bad=0 |

`opencode/` 下另有定向用例和单元测试台，详见 `opencode/README.md`。

## 当前结果

| 项 | 值 |
|---|---|
| Fmax（seed 7，`--freq 50`，布线后） | **59.32 MHz** |
| LUT4 | 17948 |
| TRELLIS_FF | 5972 |
| DP16KD | 40 / 56（I/D cache 各 16 + ROM 8） |
| DPR16X4 | 488 |

nextpnr 日志中有两个 `Max frequency`：第一个是布局后估计，最后一个（布线后）才是实际值。

## 已知限制

- 无 PMP：S/U 模式只能依靠 Sv32 的 PTE 权限隔离
- 无 M / A 扩展，无浮点与压缩指令
- PMA 只有 2 位属性，没有不可缓存窗口、W/X/atomic 属性
- ROM 仅 4 KiB，剩余 EBR 约 36 KiB；更大程序需要从 SPI flash 加载
- 运行中 PLL 失锁不会复位（`rst_gen` 只在 `!rst_n` 时工作）
- 板级未连接外部中断源；`wfi` 依赖 `mip & mie`，没有中断源时会一直等待

## 参考文档

- `docs/RV32I_Zicsr_Ref.md`：ISA / CSR / 异常 / 中断 / MMU / SDRAM 本地中文参考
- `AGENTS.md`：构建、架构、板级细节与调试注意事项
- `opencode/README.md`：定向测试用例说明

## 许可证

MIT License，Copyright (c) 2026 lyfwmcn。
