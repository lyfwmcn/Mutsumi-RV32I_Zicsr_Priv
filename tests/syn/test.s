# tests/syn/test.s
#
# Board test for the iCESugar-Pro: repeatedly print a message on the UART and
# blink the activity LEDs.
#
# The bus turns a store to 0xFFC into serial output (syn/system_bus.v):
#   sb -> one byte, sw -> four bytes (lane order), 8N1 @ 115200.
# The bus back-pressures the CPU until each byte is sent, so no delay is needed
# between the stores of a message.
#
# Because the CPU stalls until a byte is shifted out (~87 us at 115200),
# consecutive sb's are naturally paced; the outer delay loop only controls the
# gap between whole messages.

.equ UART,  0xFFC            # write a byte here -> one character out

.section .text
.globl _start

_start:
    li   s0, UART

loop:
    # ---- message: "Mutsumi RV32I\r\n" ----
    li   t0, 'M'
    sb   t0, 0(s0)
    li   t0, 'u'
    sb   t0, 0(s0)
    li   t0, 't'
    sb   t0, 0(s0)
    li   t0, 's'
    sb   t0, 0(s0)
    li   t0, 'u'
    sb   t0, 0(s0)
    li   t0, 'm'
    sb   t0, 0(s0)
    li   t0, 'i'
    sb   t0, 0(s0)
    li   t0, ' '
    sb   t0, 0(s0)
    li   t0, 'R'
    sb   t0, 0(s0)
    li   t0, 'V'
    sb   t0, 0(s0)
    li   t0, '3'
    sb   t0, 0(s0)
    li   t0, '2'
    sb   t0, 0(s0)
    li   t0, 'I'
    sb   t0, 0(s0)
    li   t0, '\r'
    sb   t0, 0(s0)
    li   t0, '\n'
    sb   t0, 0(s0)

    # ---- pause between messages (~0.5 s at 25 MHz) ----
    li   t1, 0x100000
delay:
    addi t1, t1, -1
    bne  t1, x0, delay

    j    loop
