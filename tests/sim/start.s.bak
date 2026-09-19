.section .text.boot
.globl _start

_start:
	la sp, stack_top
	la t0, trap_entry
	csrw mtvec, t0
	la t0, trap_entry1
	csrw stvec, t0
    # li t0, 8
    # csrw medeleg, t0
    # li t0, 2048
    # csrs mstatus, t0
    # la t0, e
    # csrw mepc, t0
    # mret
# e:
# 	ebreak
#     li t0, 4092
#     li t1, 65
#     sw t1, 0(t0)
    la t0, 128
    csrs mie, t0
    la t0, 8
    csrs mstatus, t0
1:
    j 1b # 0x2C

trap_entry:
    li t0, 4092 # 0x30
    li t1, 66
    sw t1, 0(t0)
    mret # 0x40

trap_entry1:
    li t0, 4092
    li t1, 67
    sw t1, 0(t0)
    csrr t2, sepc
    addi t2, t2, 4
    csrw sepc, t2
    sret
