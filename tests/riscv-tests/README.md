# riscv-tests：rv32ui-p

用 Verilator 跑 `riscv-tests` 的 `rv32ui-p-*`（RV32I 物理地址测试）。

## 当前结果

在本仓库当前 RTL 上：

```text
rv32ui-p: 42 passed, 0 failed
```

测试集版本（本地验证时）：

```text
riscv-tests 3df703c
```

## 准备 riscv-tests

需要 riscv-tests 源码和它的 `env` 子模块：

```bash
git clone --recursive https://github.com/riscv-software-src/riscv-tests.git /tmp/riscv-tests
export RISCV_TESTS=/tmp/riscv-tests
```

如果已经 clone 但没初始化子模块：

```bash
cd /tmp/riscv-tests
git submodule update --init env
```

## 运行

```bash
# 全部 rv32ui-p
python3 tests/riscv-tests/run_rv32ui.py

# 只跑指定测试
python3 tests/riscv-tests/run_rv32ui.py --test add --test ma_data

# 强制重新编译仿真器
python3 tests/riscv-tests/run_rv32ui.py --rebuild
```

需要 `riscv64-unknown-elf-gcc`、`objcopy`、`verilator`。  
中间产物在 `build/rv32ui/`，可以直接删除。

## 测试环境说明

- 测试镜像链接在 `0x0001_0000`；
- 地址 0 放一条 trampoline：`j 0x10000`；
- `tohost` 放在 `0x0200_0000`（Device 区），TB 锁存写入值并判断 PASS/FAIL；
- 测试代码运行在 U 模式，trap 回 M 模式的标准 `trap_vector`；
- `env/p/riscv_test.h` 是 riscv-tests 原版头文件的副本（沿用 riscv-tests 的许可证），
去掉了本核没有的 `INIT_RNMI`（NMI CSR）和 `INIT_PMP`（PMP CSR）；
- `env/p/link.ld` 把 `.text` 放在 `0x10000`，`.tohost` 放在 `0x0200_0000`。

## 非对齐访存

当前核**没有硬件非对齐 load/store 支持**，非对齐访问会触发 `mcause=4/6`。

`ma_data` 测试要求实现能直接完成非对齐 access。为了让它在不修改核的情况下跑通，
`env/p/misalign.S` 提供了一个 `mtvec_handler`：

- 捕获 `mcause=4`（load misaligned）和 `mcause=6`（store misaligned）；
- 从 `mtval` 取有效地址；
- 用 `lbu`/`sb` 逐字节完成 16/32 位 load/store；
- 更新 `mepc += 4` 后 `mret`。

这是**测试环境层面的软件模拟**，不是 RTL 支持。去掉 `misalign.S` 后，
其余 41 项仍通过，`ma_data` 会失败。

## 未覆盖

- `rv32ui-v-*`：已搭了一个 WIP 环境（`opencode/riscv-tests-v/`，被 gitignore）。
  修复 `satp` flush glitch 和 `d_save_set_d` 后 41/42 通过；仅 `ma_data` 的
  S 模式非对齐模拟还没过；
- `rv32um/ua/uc`：分别需要 M/A/C 扩展；
- `rv32mi/si`：还需要定时器、PMP、Zicntr 等特权功能。

## 本次发现并修复的 RTL 问题

`bgeu` / `bltu` 的测试暴露了 `src/core/alu.v` 的 `cf` 计算错误：

- 原实现用 `diff_ext[32] ^ (sub & (|b))`，当 `b == 0` 时无符号比较结果错误；
- 现在直接使用减法借位：`cf = sub ? borrow : add_ext[32]`。

修复后 `bgeu`、`bltu` 全部通过。

另外，尝试 `rv32ui-v` 时发现 Sv32 的 PTE.U 权限判断方向反了：

- 原实现 `U != privilege[0]`，导致 U 模式拒绝 U 页、S 模式拒绝非 U 页；
- 已改为 U 模式要求 U=1，S 模式要求 U=0（SUM 暂未实现）。

`opencode/tb/tb_uncore.v` 仍然 34/34，`tb_boot` 仍然 5/5。

尝试 `rv32ui-v` 时还发现 `trap_csr_bypass` 的 `flush` 分支把 `satp`（以及
`mtvec/stvec/mepc/sepc`）清 0 一拍：

- `sret` 后的第一笔用户取指正好落在这一拍，抓到 `satp=0`；
- I 侧按 bare 地址翻译并缓存了错误结果，表现为“PWC/TLB 拿到旧翻译”；
- 现在 `flush` 时回落到已提交的 `cur_*`，不再产生一拍 0。

修复后 `v simple/add/beq/lw/jal` 通过。`v sw` 继续定位到硬件补 A/D：

- `d_save_set_d` 从来没有被置 1，导致 `d_set_d` 永远锁存 0；
- store 的 D 位因此永远置不上，`D_AD_FILL` 反复做 A 更新；
- 补上 `d_save_set_d = 1` 后，`v sw` / `v fence_i` 都通过。

现在 `rv32ui-v` 是 **41/42**，只剩 `ma_data`，需要 S 模式非对齐访存模拟
（当前 vm.c 里的尝试还没完全通过）。

回归结果仍然是 `rv32ui-p` 42/42、`tb_uncore` 34/34、`tb_boot` 5/5。
