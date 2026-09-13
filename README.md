# 平台及工具链
1. 平台：x86_64 Linux
2. 工具链：make, iverilog, riscv64-unknown-elf-gcc, python3, yosys, nextpnr-ecp5, ecppack
# 使用方法
## 模拟
1. 在项目根目录执行 make/make all/make sim
## 综合
1. 连接电脑和 iCESugar-Pro v1.3
2. 挂载到 /run/media/$USER
3. 在项目根目录执行 make synth
# 开发进度
## 目前实现的异常处理机制
1. 将发现的先后顺序作为优先级选出异常
2. 如果有异常，将权限改为 M
3. 修改 mstatus.MPP
4. 将异常指令地址写入 mepc
5. 按照各自的规则写入 mtval
6. 修改 mcause
7. 直接跳转到 mtvec
## 要实现的返回机制
1. 根据返回指令类型将 MPP/SPP 加载到特权级，MPP/SPP 清零
2. 修改 MIE/SIE，MPIE/SPIE 置 1
3. 跳转到 mepc/sepc
* mret: 读取 MPP, MPIE, mepc, 修改特权级，MPP, MIE, MPIE
* sret: 读取 SPP, SPIE, sepc, 修改特权级，SPP, SIE, SPIE
## 要实现的异常处理机制
1. 将发现的先后顺序作为优先级选出异常
2. 如果有异常，依据 medeleg 将权限改为 M/S，但 M 时必须设 M
3. 修改 mstatus.MPP/MPIE/MIE 或 mstatus.SPP/SPIE/SIE
4. 将异常指令地址写入 mepc/sepc
5. 按照各自的规则写入 mtval/stval
6. 修改 mcause/scause
7. 直接跳转到 mtvec/stvec
* 读取 medeleg, 特权级，MIE, mtvec, 修改特权级, MPP, MIE, MPIE, mtval, mepc, mcause
* 读取 medeleg, 特权级，SIE, stvec, 修改特权级, SPP, SIE, SPIE, stval, sepc, scause
## 中断处理机制
1. 每周期检查 mip 中有没有 1
2. 若有 1，且 mie 对应位 = 1
3. 根据 mideleg 对应位和目前特权级决定交给 M/S 处理
4. 若决定交给 M 处理，检查 mstatus.MIE，若决定交给 S 处理，检查 mstatus.SIE
5. 在满足条件的中选择优先级最高的
6. 修改 mstatus.MPP/MPIE/MIE 或 mstatus.SPP/SPIE/SIE
7. 将未执行指令地址写入 mepc/sepc
8. mtval/stval 设置 0
9. 修改 mcause/scause
10. 直接跳转到 mtvec/stvec
* 读取 mip, mie, mideleg, 特权级, MIE, mtvec, 修改 MPP, MPIE, MIE, mepc, mtval, mcause
* 读取 mip, mie, mideleg, 特权级, SIE, stvec, 修改 SPP, SPIE, SIE, sepc, stval, scause
