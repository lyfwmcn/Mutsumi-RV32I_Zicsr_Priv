# 上板自检程序（周期性重复，方便任意时刻抓串口）
#   每轮：把镜像区 0x00..0xBF（12 行 x 16 字节）逐字节读回经 UART 发出，行间用 '~' 分隔，
#         末尾发 '\n'，然后延时约 0.2~0.5 s 再重复。
# 主机侧拿 build/boot.bin 逐字节对比，就能看出哪几行/哪几个字节被写坏或读坏。

    .section .text
    .globl _start
_start:
    j    main

main:
    li   x1, 0x02000000        # UART 设备地址（pma == 2）

outer:
    li   x3, 0                 # 行计数
    li   x4, 0                 # 当前地址

line_loop:
    li   x5, 0                 # 行内字节计数
byte_loop:
    add  x6, x4, x5
    lbu  x2, 0(x6)
    sb   x2, 0(x1)
    jal  x9, delay
    addi x5, x5, 1
    li   x7, 16
    bne  x5, x7, byte_loop

    li   x2, 0x7e              # '~' 行分隔
    sb   x2, 0(x1)
    jal  x9, delay

    addi x4, x4, 16
    addi x3, x3, 1
    li   x7, 12
    bne  x3, x7, line_loop

    li   x2, 10                # '\n' 一轮结束
    sb   x2, 0(x1)
    jal  x9, delay

    # 轮间延时：约 2_000_000 x 3 拍
    li   x11, 2000000
wait:
    addi x11, x11, -1
    bne  x11, x0, wait
    j    outer

# ---- 约 180us（3000 x 3 拍 @50MHz），保证 UART 发完一个字节 ----
delay:
    li   x10, 3000
d1:
    addi x10, x10, -1
    bne  x10, x0, d1
    jalr x0, 0(x9)
