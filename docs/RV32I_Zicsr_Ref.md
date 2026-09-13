# 指令格式
## R 型指令
* funct7 + Rs2 + Rs1 + funct3 + Rd + opcode
* opcode = 0110011

| instr | funct3 | funct7[5] |
| :---: | :----: | :-------: |
|  add  |  000   |     0     |
|  sub  |  000   |     1     |
|  sll  |  001   |     0     |
|  slt  |  010   |     0     |
| sltu  |  011   |     0     |
|  xor  |  100   |     0     |
|  srl  |  101   |     0     |
|  sra  |  101   |     1     |
|  or   |  110   |     0     |
|  and  |  111   |     0     |
## I 型指令
### 算术型指令
* imm[11:0] + Rs1 + funct3 + Rd + opcode
* opcode = 0010011

| instr | funct3 |
| :---: | :----: |
| addi  |  000   |
| slli  |  001   |
| slti  |  010   |
| sltiu |  011   |
| xori  |  100   |
| srli  |  101   |
| srai  |  101   |
|  ori  |  110   |
| andi  |  111   |
* srli 和 srai 由 imm[10] 区分
* srli: imm[10] = 0
* srai: imm[10] = 1
### Load 型指令
* opcode = 0000011

| instr | funct3 |
| :---: | :----: |
|  lb   |  000   |
|  lh   |  001   |
|  lw   |  010   |
|  lbu  |  100   |
|  lhu  |  101   |
### jalr 指令
* opcode = 1100111

| instr | funct3 |
| :---: | :----: |
| jalr  |  000   |
### SYSTEM 指令
* opcode = 1110011

|   instr    |      imm      | Rs1 | funct3 |  Rd  |
| :--------: | :-----------: | :-: | :----: | :--: |
|   ecall    | 000000000000  |  0  |  000   |  0   |
|   ebreak   | 000000000001  |  0  |  000   |  0   |
|    mret    | 001100000010  |  0  |  000   |  0   |
|    sret    | 000100000010  |  0  |  000   |  0   |
|    wfi     | 000100000101  |  0  |  000   |  0   |
|   csrrw    |               |     |  001   |      |
|   csrrs    |               |     |  010   |      |
|   csrrc    |               |     |  011   |      |
|   csrrwi   |               |     |  101   |      |
|   csrrsi   |               |     |  110   |      |
|   csrrci   |               |     |  111   |      |
### FENCE 指令
* opcode = 0001111
* imm = {fm, pred, succ}

|   instr    | fm  | pred | succ | Rs1 | funct3 |  Rd  |
| :--------: | :-: | :--: | :--: | :-: | :----: | :--: |
|   ecall    |  0  |      |      |  0  |  000   |  0   |
* pred/succ: 

| bit | function |
| :-: | :------: |
|  0  |    W     |
|  1  |    R     |
|  2  |    O     |
|  3  |    I     |
## U 型指令
* imm[31:12] + Rd + opcode

| instr | opcode |
| :---: | :----: |
|  lui  |0110111 |
| auipc |0010111 |
## S 型指令
* imm[11:5] + Rs2 + Rs1 + funct3 + imm[4:0] + opcode
* opcode = 0100011

| instr | funct3 |
| :---: | :----: |
|  sb   |  000   |
|  sh   |  001   |
|  sw   |  010   |
## B 型指令
* imm[12] + imm[10:5] + Rs2 + Rs1 + funct3 + imm[4:1] + imm[11] + opcode
* opcode = 1100011

| instr | funct3 |
| :---: | :----: |
|  beq  |  000   |
|  bne  |  001   |
|  blt  |  100   |
|  bge  |  101   |
| bltu  |  110   |
| bgeu  |  111   |
## J 型指令
* opcode = 1101111
* imm[20] + imm[10:1] + imm[11] + imm[19:12] + Rd + opcode
# CSR 寄存器
|    name    | addr |
| :--------: | :--: |
|  sstatus   | 100  |
|    sie     | 104  |
|   stvec    | 105  |
|  sscratch  | 140  |
|    sepc    | 141  |
|   scause   | 142  |
|   stval    | 143  |
|    sip     | 144  |
|    satp    | 180  |
|  mstatus   | 300  |
|    misa    | 301  |
|  medeleg   | 302  |
|  mideleg   | 303  |
|    mie     | 304  |
|   mtvec    | 305  |
|  mscratch  | 340  |
|    mepc    | 341  |
|   mcause   | 342  |
|   mtval    | 343  |
|    mip     | 344  |
|   mcycle   | B00  |
|  minstret  | B02  |
|  mcycleh   | B80  |
| minstreth  | B82  |
|  mhartid   | F14  |
## mstatus/sstatus
|  bit  | name |              function                | sstatus | Read-Only |
| :---: | :--: | :----------------------------------: | :-----: | :-------: |
|   0   | UIE  | User Interrupt Enable                |    *    |     0     |
|   1   | SIE  | Supervisor Interrupt Enable          |    *    |           |
|   3   | MIE  | Machine Interrupt Enable             |         |           |
|   4   | UPIE | User Previous Interrupt Enable       |    *    |     0     |
|   5   | SPIE | Supervisor Previous Interrupt Enable |    *    |           |
|   7   | MPIE | Machine Previous Interrupt Enable    |         |           |
|   8   | SPP  | Supervisor Previous Privilege        |    *    |           |
| 12:11 | MPP  | Machine Previous Privilege           |         |           |
| 14:13 |  FS  | Floating-Point Status                |    *    |     0     |
| 16:15 |  XS  | Extension Status                     |    *    |     0     |
|  17   | MPRV | Memory Privilege                     |         |           |
|  18   | SUM  | Supervisor User Memory Access        |    *    |           |
|  19   | MXR  | Make Executable Readable             |    *    |           |
|  20   | TVM  | Trap Virtual Memory                  |         |           |
|  21   |  TW  | Time Wait                            |         |           |
|  22   | TSR  | Trap SRET                            |         |           |
|  31   |  SD  | State Dirty                          |    *    |     0     |
* UIE/SIE/MIE：控制对应等级中断是否能被处理
* UPIE/SPIE/MPIE：保存中断发生前的 XIE
* SPP/MPP：进入对应权限态之前的权限态
* MPRV：控制 M 态下 load/store 是否模拟在 MPP 中保存的特权级下进行
* SUM：控制 S 态下能否访问 U 态内存
* MXR：控制可执行不可读的页表项是否可读
* TVM：控制是否禁止 S 态操作 satp，刷新 TLB 缓存
* TW：控制是否禁止 S 态无休止等待中断
* TSR：控制是否禁止 S 态返回 U 态
* FS/XS/SD：记录对应寄存器是否变化
## mie/sie
| bit | name |               function               | sie | Read-Only |
| :-: | :--: | :----------------------------------: | :-: | :-------: |
|  0  | USIE | User Software Interrupt Enable       |  *  |     0     |
|  1  | SSIE | Supervisor Software Interrupt Enable |  *  |           |
|  3  | MSIE | Machine Software Interrupt Enable    |     |           |
|  4  | UTIE | User Timer Interrupt Enable          |  *  |     0     |
|  5  | STIE | Supervisor Timer Interrupt Enable    |  *  |           |
|  7  | MTIE | Machine Timer Interrupt Enable       |     |           |
|  8  | UEIE | User External Interrupt Enable       |  *  |     0     |
|  9  | SEIE | Supervisor External Interrupt Enable |  *  |           |
| 11  | MEIE | Machine External Interrupt Enable    |     |           |
* 控制对应中断是否能被处理
## mtvec/stvec
| mtvec[1:0] |           address            |
| :--------: | :--------------------------: |
|     00     | BASE                         |
|     01     | BASE + mcause.Async_Code * 4 |
* 控制中断或异常的跳转地址，注意两种模式下异常都是直接跳转到 BASE
## mcause/scause
| bit  |      name      |
| :--: | :------------: |
| 30:0 | Exception Code |
|  31  | Interrupt      |
* 记录中断或异常的原因
## mepc/sepc
* 中断或异常发生时的 PC
## medeleg/mideleg
* 记录对应中断或异常是否委托给 S 态处理
* mideleg 的 U 态中断位固定为 0
## mip/sip
* 记录当前哪些中断挂起，sip 无独立寄存器，不映射 M 态中断
* U 态中断固定为 0
## mtval/stval
* 中断或异常的附加信息
## mscratch/sscratch
* 对应态中间寄存器
## pmpcfg0-pmpcfg3
* 编址 0x3A0-0x3A3
* pmpcfg 包含 4 个 8 位的控制块
* 控制块结构：

| bit | name |       function        |
| :-: | :--: | :-------------------: |
|  0  |  R   | Read                  |
|  1  |  W   | Write                 |
|  2  |  X   | Execute               |
| 4:3 |  A   | Address Matching Mode |
|  7  |  L   | Lock                  |
* Address Matching Mode:

| code | name  |            function            |                                      address                                       |
| :--: | :---: | :----------------------------: | :--------------------------------------------------------------------------------: |
|  00  |  OFF  |                                |                                                                                    |
|  01  |  TOR  | Top of Range                   | pmpaddr[i - 1] << 2 ~ pmpaddr[i] << 2 - 1                                          |
|  10  |  NA4  | Naturally Aligned 4-Byte       | pmpaddr[i] << 2 ~ pmpaddr[i] << 2 + 3                                              |
|  11  | NAPOT | Naturally Aligned Power-of-Two | startaddr = pmpaddr[i] 清除尾部连续 1 后左移 2，大小 = 2 ^ (尾部连续 1 的个数 + 3) |
## pmpaddr0-pmpaddr15
* 编址 0x3B0-0x3BF
## misa
|  bit  |    name    |  function   |
| :---: | :--------: | :---------: |
| 31:30 | MXLEN      | Word Length |
| 25:0  | Extensions |             |
* MXLEN:

| code | length |
| :--: | :----: |
|  01  |   32   |
|  10  |   64   |
|  11  |  128   |
## satp
|  bit  | name |         function         |
| :---: | :--: | :----------------------: |
|  31   | MODE |                          |
| 30:22 | ASID | Address Space Identifier |
| 21:0  | PPN  | Physical Page Number     |
* 记录根页表的物理地址
# 异常和中断
## 异常
* 异常类型：

|  code  |              name              |          mtval           |
| :----: | :----------------------------: | :----------------------: |
|  0000  | Instruction address misaligned | 导致异常的指令目标地址   |
|  0001  | Instruction access fault       | 导致异常的指令地址       |
|  0010  | Illegal instruction            | 非法指令本身             |
|  0011  | Breakpoint                     | 0                        |
|  0100  | Load address misaligned        | 产生非对齐访问的有效地址 |
|  0101  | Load access fault              | 产生访问异常的有效地址   |
|  0110  | Store/AMO address misaligned   | 产生非对齐访问的有效地址 |
|  0111  | Store/AMO access fault         | 产生访问异常的有效地址   |
|  1000  | Environment call from U-mode   | 0                        |
|  1001  | Environment call from S-mode   | 0                        |
|  1011  | Environment call from M-mode   | 0                        |
|  1100  | Instruction page fault         | 导致异常的指令地址       |
|  1101  | Load page fault                | 产生异常的有效地址       |
|  1111  | Store/AMO page fault           | 产生异常的有效地址       |
* 异常检测顺序：12/1/2/3-8-9-11/0-(4/13/5)-(6/15/7)
## 中断
* 中断类型：

|  code  |              name              |
| :----: | :----------------------------: |
|  0000  | User software interrupt        |
|  0001  | Supervisor software interrupt  |
|  0011  | Machine software interrupt     |
|  0100  | User timer interrupt           |
|  0101  | Supervisor timer interrupt     |
|  0111  | Machine timer interrupt        |
|  1000  | User external interrupt        |
|  1001  | Supervisor external interrupt  |
|  1011  | Machine external interrupt     |
* 中断优先级：M > S > U，外部中断 > 定时器中断 > 软件中断
# 虚拟内存与页表
* 页表是一种特殊的数据结构，它将物理内存以 4KiB/4MiB 划分为页，并提供了虚拟页到物理页的映射方法，通常由 1024 个 32 位 PTE 组成，占 4KiB，自身刚好占用一个小页
* PTE 结构：

|  bit  |   name   |
| :---: | :------: |
| 31:10 | PPN      |
|   7   | Dirty    |
|   6   | Accessed |
|   5   | Global   |
|   4   | User     |
|   3   | Execute  |
|   2   | Write    |
|   1   | Read     |
|   0   | Valid    |
* 32 位虚拟地址划分：

|  bit  |  name  |
| :---: | :----: |
| 31:22 | VPN[1] |
| 21:12 | VPN[0] |
| 11:0  | offset |
## 一级寻址
* 页表 PTE = satp.PPN << 12 + VPN[1] << 2
* 物理地址 = 页表 PTE.PPN << 22 + VPN[0] << 12 + offset
## 二级寻址
* 二级页表 PTE = satp.PPN << 12 + VPN[1] << 2
* 页表 PTE = 二级页表 PTE.PPN << 12 + VPN[0] << 2
* 物理地址 = 页表 PTE.PPN << 12 + offset
# Hart 运行
