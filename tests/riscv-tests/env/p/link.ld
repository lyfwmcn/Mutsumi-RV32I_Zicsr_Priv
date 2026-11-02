OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
  . = 0x00010000;
  .text.init : { *(.text.init) }
  . = ALIGN(0x1000);
  .text : { *(.text) }
  . = ALIGN(0x1000);
  .data : { *(.data) }
  .bss : { *(.bss) }
  _end = .;
  . = ALIGN(0x1000);
  .tohost 0x02000000 : { *(.tohost) }
}
