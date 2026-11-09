/******************************************************************
 * Linker Script for Zynq-7000 (Cortex-A9 Standalone)
 * Target: Digilent Zybo Z7 (XC7Z020-1CLG400C)
 * Memory: DDR3 512 MB (0x00100000 to 0x1FFFFFFF)
 ******************************************************************/

_STACK_SIZE = DEFINED(_STACK_SIZE) ? _STACK_SIZE : 0x20000;
_HEAP_SIZE  = DEFINED(_HEAP_SIZE)  ? _HEAP_SIZE  : 0x40000;

MEMORY
{
   ps7_ddr_0_S_AXI_BASEADDR : ORIGIN = 0x00100000, LENGTH = 0x1FF00000
   ps7_ram_0_S_AXI_BASEADDR : ORIGIN = 0x00000000, LENGTH = 0x00030000
   ps7_ram_1_S_AXI_BASEADDR : ORIGIN = 0xFFFF0000, LENGTH = 0x0000FE00
}

ENTRY(_vector_table)

SECTIONS
{
.boot : {
   *(.boot)
} > ps7_ddr_0_S_AXI_BASEADDR

.text : {
   *(.text)
   *(.text.*)
   *(.gnu.linkonce.t.*)
} > ps7_ddr_0_S_AXI_BASEADDR

.rodata : {
   __rodata_start = .;
   *(.rodata)
   *(.rodata.*)
   *(.gnu.linkonce.r.*)
   __rodata_end = .;
} > ps7_ddr_0_S_AXI_BASEADDR

.data : {
   __data_start = .;
   *(.data)
   *(.data.*)
   *(.gnu.linkonce.d.*)
   __data_end = .;
} > ps7_ddr_0_S_AXI_BASEADDR

.bss (NOLOAD) : {
   . = ALIGN(64);
   __bss_start__ = .;
   *(.bss)
   *(.bss.*)
   *(.gnu.linkonce.b.*)
   *(COMMON)
   . = ALIGN(64);
   __bss_end__ = .;
} > ps7_ddr_0_S_AXI_BASEADDR

.heap (NOLOAD) : {
   . = ALIGN(64);
   _heap = .;
   HeapBase = .;
   _heap_start = .;
   . += _HEAP_SIZE;
   _heap_end = .;
   HeapLimit = .;
} > ps7_ddr_0_S_AXI_BASEADDR

.stack (NOLOAD) : {
   . = ALIGN(64);
   _stack_end = .;
   . += _STACK_SIZE;
   . = ALIGN(64);
   _stack = .;
   __stack = _stack;
   StackLimit = _stack_end;
   StackTop = _stack;
} > ps7_ddr_0_S_AXI_BASEADDR
}
