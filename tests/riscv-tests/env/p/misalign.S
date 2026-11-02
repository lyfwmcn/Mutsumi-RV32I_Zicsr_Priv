// rv32ui 非对齐访存软件模拟：mtvec_handler
// 只处理 load/store address misaligned（mcause=4/6），其余异常按失败处理。
// 所有寄存器先保存到 misalign_save，处理完恢复；测试本身不需要非对齐硬件支持。
    .section .text
    .globl mtvec_handler
mtvec_handler:
    csrrw t0, mscratch, t0          # t0 = save base, mscratch = 原 t0
    sw x1, 4(t0)
    sw x2, 8(t0)
    sw x3, 12(t0)
    sw x4, 16(t0)
    sw x6, 24(t0)
    sw x7, 28(t0)
    sw x8, 32(t0)
    sw x9, 36(t0)
    sw x10, 40(t0)
    sw x11, 44(t0)
    sw x12, 48(t0)
    sw x13, 52(t0)
    sw x14, 56(t0)
    sw x15, 60(t0)
    sw x16, 64(t0)
    sw x17, 68(t0)
    sw x18, 72(t0)
    sw x19, 76(t0)
    sw x20, 80(t0)
    sw x21, 84(t0)
    sw x22, 88(t0)
    sw x23, 92(t0)
    sw x24, 96(t0)
    sw x25, 100(t0)
    sw x26, 104(t0)
    sw x27, 108(t0)
    sw x28, 112(t0)
    sw x29, 116(t0)
    sw x30, 120(t0)
    sw x31, 124(t0)
    csrr t1, mscratch
    sw t1, 20(t0)
    csrw mscratch, t0

    csrr t3, mcause
    li   t4, 4
    beq  t3, t4, mis_load
    li   t4, 6
    beq  t3, t4, mis_store

    # 未处理异常：写 tohost 后停住
    li   t0, 0x02000000
    li   t1, 0x539
    sw   t1, 0(t0)
1:  j    1b

mis_load:
    csrr t4, mepc
    csrr t5, mtval
    lw   a3, 0(t4)
    srli a2, a3, 12
    andi a2, a2, 7                   # funct3
    srli a1, a3, 7
    andi a1, a1, 31                  # rd

    lbu  a0, 0(t5)
    lbu  a4, 1(t5)
    slli a4, a4, 8
    or   a0, a0, a4

    li   a4, 5
    beq  a2, a4, mis_load_commit     # lhu
    li   a4, 1
    beq  a2, a4, mis_load_h           # lh

    lbu  a4, 2(t5)
    slli a4, a4, 16
    or   a0, a0, a4
    lbu  a4, 3(t5)
    slli a4, a4, 24
    or   a0, a0, a4
    j    mis_load_commit
mis_load_h:
    slli a0, a0, 16
    srai a0, a0, 16
mis_load_commit:
    addi t4, t4, 4
    csrw mepc, t4
    csrr t6, mscratch
    la   t3, mis_rd_table
    slli a1, a1, 3
    add  t3, t3, a1
    jr   t3

mis_store:
    csrr t4, mepc
    csrr t5, mtval
    lw   a3, 0(t4)
    srli a2, a3, 12
    andi a2, a2, 7                   # funct3
    srli a1, a3, 20
    andi a1, a1, 31                  # rs2
    addi t4, t4, 4
    csrw mepc, t4
    csrr t6, mscratch
    la   t3, mis_rs2_table
    slli a1, a1, 3
    add  t3, t3, a1
    jr   t3

mis_store_do:
    sb   a0, 0(t5)
    srli a4, a0, 8
    sb   a4, 1(t5)
    li   a4, 1
    beq  a2, a4, mis_ret             # sh
    srli a4, a0, 16
    sb   a4, 2(t5)
    srli a4, a0, 24
    sb   a4, 3(t5)

mis_ret:
    csrr t6, mscratch
    lw x1, 4(t6)
    lw x2, 8(t6)
    lw x3, 12(t6)
    lw x4, 16(t6)
    lw x5, 20(t6)
    lw x6, 24(t6)
    lw x7, 28(t6)
    lw x8, 32(t6)
    lw x9, 36(t6)
    lw x10, 40(t6)
    lw x11, 44(t6)
    lw x12, 48(t6)
    lw x13, 52(t6)
    lw x14, 56(t6)
    lw x15, 60(t6)
    lw x16, 64(t6)
    lw x17, 68(t6)
    lw x18, 72(t6)
    lw x19, 76(t6)
    lw x20, 80(t6)
    lw x21, 84(t6)
    lw x22, 88(t6)
    lw x23, 92(t6)
    lw x24, 96(t6)
    lw x25, 100(t6)
    lw x26, 104(t6)
    lw x27, 108(t6)
    lw x28, 112(t6)
    lw x29, 116(t6)
    lw x30, 120(t6)
    lw t6, 124(t6)
    mret

    .section .data
    .align 4
mis_rd_table:
    sw a0, 0(t6); j mis_ret
    sw a0, 4(t6); j mis_ret
    sw a0, 8(t6); j mis_ret
    sw a0, 12(t6); j mis_ret
    sw a0, 16(t6); j mis_ret
    sw a0, 20(t6); j mis_ret
    sw a0, 24(t6); j mis_ret
    sw a0, 28(t6); j mis_ret
    sw a0, 32(t6); j mis_ret
    sw a0, 36(t6); j mis_ret
    sw a0, 40(t6); j mis_ret
    sw a0, 44(t6); j mis_ret
    sw a0, 48(t6); j mis_ret
    sw a0, 52(t6); j mis_ret
    sw a0, 56(t6); j mis_ret
    sw a0, 60(t6); j mis_ret
    sw a0, 64(t6); j mis_ret
    sw a0, 68(t6); j mis_ret
    sw a0, 72(t6); j mis_ret
    sw a0, 76(t6); j mis_ret
    sw a0, 80(t6); j mis_ret
    sw a0, 84(t6); j mis_ret
    sw a0, 88(t6); j mis_ret
    sw a0, 92(t6); j mis_ret
    sw a0, 96(t6); j mis_ret
    sw a0, 100(t6); j mis_ret
    sw a0, 104(t6); j mis_ret
    sw a0, 108(t6); j mis_ret
    sw a0, 112(t6); j mis_ret
    sw a0, 116(t6); j mis_ret
    sw a0, 120(t6); j mis_ret
    sw a0, 124(t6); j mis_ret
mis_rs2_table:
    lw a0, 0(t6); j mis_store_do
    lw a0, 4(t6); j mis_store_do
    lw a0, 8(t6); j mis_store_do
    lw a0, 12(t6); j mis_store_do
    lw a0, 16(t6); j mis_store_do
    lw a0, 20(t6); j mis_store_do
    lw a0, 24(t6); j mis_store_do
    lw a0, 28(t6); j mis_store_do
    lw a0, 32(t6); j mis_store_do
    lw a0, 36(t6); j mis_store_do
    lw a0, 40(t6); j mis_store_do
    lw a0, 44(t6); j mis_store_do
    lw a0, 48(t6); j mis_store_do
    lw a0, 52(t6); j mis_store_do
    lw a0, 56(t6); j mis_store_do
    lw a0, 60(t6); j mis_store_do
    lw a0, 64(t6); j mis_store_do
    lw a0, 68(t6); j mis_store_do
    lw a0, 72(t6); j mis_store_do
    lw a0, 76(t6); j mis_store_do
    lw a0, 80(t6); j mis_store_do
    lw a0, 84(t6); j mis_store_do
    lw a0, 88(t6); j mis_store_do
    lw a0, 92(t6); j mis_store_do
    lw a0, 96(t6); j mis_store_do
    lw a0, 100(t6); j mis_store_do
    lw a0, 104(t6); j mis_store_do
    lw a0, 108(t6); j mis_store_do
    lw a0, 112(t6); j mis_store_do
    lw a0, 116(t6); j mis_store_do
    lw a0, 120(t6); j mis_store_do
    lw a0, 124(t6); j mis_store_do

    .section .bss
    .align 4
    .globl misalign_save
misalign_save:
    .space 128
