.section .text.boot
.globl _start

_start:
    li t0, 4092
    li t1, 65
    sw t1, 0(t0)
1:
    j 1b
