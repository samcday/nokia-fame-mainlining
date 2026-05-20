/* SPDX-License-Identifier: MIT */

ENTRY(_start)

SECTIONS
{
	. = 0x82000000;
	.text : {
		*(.text*)
		*(.rodata*)
	}
	/DISCARD/ : {
		*(.comment*)
		*(.ARM.attributes*)
		*(.note*)
	}
}
