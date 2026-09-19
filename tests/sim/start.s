# tests/sim/start.s
#
# Self-checking test for S-mode exception delegation.
#
# Flow:
#   1. In M-mode, point mtvec at an M handler and stvec at an S handler, and
#      delegate "environment call from S-mode" (cause 9) via medeleg.
#   2. Enter S-mode with mret (MPP = S, mepc = s_entry).
#   3. In S-mode, execute ecall. Because cause 9 is delegated and we are in
#      S-mode, the trap must go to the S handler: scause = 9, sepc = the ecall,
#      stval = 0, and sstatus.SPP = 1.
#   4. The S handler advances sepc and returns with sret.
#   5. A non-delegated cause (ebreak, 3) from S-mode must still reach the M
#      handler, proving delegation is per-cause.
#
# Console: '.' = pass, 'F' = fail, then "OK"/"FAIL".
#
# Globals kept across the handlers:
#   s0 = failed checks       t0 = console address
#   s4 = which handler ran   (1 = M, 2 = S)
#   s1/s2/s3/s5 = scause/sepc/stval/sstatus captured by the S handler
#   s9 = mcause/mepc captured by the M handler (separate, so the two handlers
#        never clobber each other's observations)

.equ CONSOLE, 4092
.equ CH_DOT, 46
.equ CH_F,   70
.equ CH_O,   79
.equ CH_K,   75
.equ CH_A,   65
.equ CH_I,   73
.equ CH_L,   76

.section .text.boot
.globl _start

_start:
    li   t0, CONSOLE
    li   s0, 0
    li   s4, 0

    # M-mode and S-mode handlers
    la   t1, m_trap_entry
    csrw mtvec, t1
    la   t1, s_trap_entry
    csrw stvec, t1

    # delegate cause 9 (ecall from S-mode)
    li   t1, 0x200
    csrw medeleg, t1

    # enter S-mode: MPP = S (1), mepc = s_entry, then mret
    li   t1, 0x800
    csrs mstatus, t1
    la   t1, s_entry
    csrw mepc, t1
    mret

# ======================== S-mode code ========================
s_entry:
    li   s4, 0
s_ec:
    ecall                      # cause 9, delegated -> S handler

# The S handler must have run.
    li   t2, CH_DOT
    li   a3, 2
    bne  s4, a3, 1f
    j    2f
1:  li   t2, CH_F
    addi s0, s0, 1
2:  sw   t2, 0(t0)

# scause = 9
    li   t2, CH_DOT
    li   a3, 9
    bne  s1, a3, 1f
    j    2f
1:  li   t2, CH_F
    addi s0, s0, 1
2:  sw   t2, 0(t0)

# sepc = the ecall address (captured before the handler advanced it)
    li   t2, CH_DOT
    la   a3, s_ec
    bne  s2, a3, 1f
    j    2f
1:  li   t2, CH_F
    addi s0, s0, 1
2:  sw   t2, 0(t0)

# stval = 0 for ecall
    li   t2, CH_DOT
    bne  s3, x0, 1f
    j    2f
1:  li   t2, CH_F
    addi s0, s0, 1
2:  sw   t2, 0(t0)

# sstatus.SPP = 1 (the exception came from S-mode)
    li   t2, CH_DOT
    srli a0, s5, 8
    andi a0, a0, 1
    li   a3, 1
    bne  a0, a3, 1f
    j    2f
1:  li   t2, CH_F
    addi s0, s0, 1
2:  sw   t2, 0(t0)

# A non-delegated cause still goes to M: ebreak (3).
# mret then returns to S-mode at the instruction after ebreak.
    li   s4, 0
    ebreak

    li   t2, CH_DOT
    li   a3, 1              # M handler ran
    bne  s4, a3, 1f
    li   a3, 3              # and it saw cause 3
    bne  s9, a3, 1f
    j    2f
1:  li   t2, CH_F
    addi s0, s0, 1
2:  sw   t2, 0(t0)

# =========================== result ============================
    bne  s0, x0, fail
    li   t1, CH_O
    sw   t1, 0(t0)
    li   t1, CH_K
    sw   t1, 0(t0)
    j    end
fail:
    li   t1, CH_F
    sw   t1, 0(t0)
    li   t1, CH_A
    sw   t1, 0(t0)
    li   t1, CH_I
    sw   t1, 0(t0)
    li   t1, CH_L
    sw   t1, 0(t0)
end:
    j    end

# ========================= M-mode handler =========================
# Non-delegated exceptions land here. Records mcause/mepc in s9/s10 and
# resumes at mepc + 4.
m_trap_entry:
    csrw mscratch, t1
    csrr s9, mcause
    csrr s10, mepc
    li   s4, 1
    csrr t1, mepc
    addi t1, t1, 4
    csrw mepc, t1
    csrr t1, mscratch
    mret

# ========================= S-mode handler =========================
# Delegated exceptions land here. Records scause/sepc/stval/sstatus, then
# resumes at sepc + 4. Only S-mode CSRs may be accessed from here.
s_trap_entry:
    csrw sscratch, t1
    csrr s1, scause
    csrr s2, sepc
    csrr s3, stval
    csrr s5, sstatus
    li   s4, 2
    csrr t1, sepc
    addi t1, t1, 4
    csrw sepc, t1
    csrr t1, sscratch
    sret
