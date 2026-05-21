/* SPDX-License-Identifier: MIT */
/*
 * LK-safe trampoline for testing an APPSBL-linked U-Boot payload.
 *
 * Android4Lumia LK refuses boot images loaded into its aboot memory window
 * around 0x88f00000. This stub is loaded as a normal Android boot image kernel
 * at a safe low address, then copies the appended payload to the APPSBL address
 * after LK has jumped away.
 */

	.syntax unified
	.arm

#ifndef TRAMPOLINE_LOAD_ADDR
#define TRAMPOLINE_LOAD_ADDR 0x80208000
#endif
#ifndef TRAMPOLINE_META_OFFSET
#define TRAMPOLINE_META_OFFSET 0x0ff0
#endif
#ifndef TRAMPOLINE_PAYLOAD_OFFSET
#define TRAMPOLINE_PAYLOAD_OFFSET 0x1000
#endif
#ifndef TRAMPOLINE_STACK
#define TRAMPOLINE_STACK 0x82000000
#endif

	.equ META_ADDR, TRAMPOLINE_LOAD_ADDR + TRAMPOLINE_META_OFFSET
	.equ PAYLOAD_SRC, TRAMPOLINE_LOAD_ADDR + TRAMPOLINE_PAYLOAD_OFFSET

	.section .text
	.global _start
	.type _start, %function

_start:
	ldr	sp, =TRAMPOLINE_STACK

	ldr	r0, =META_ADDR
	ldr	r4, [r0, #0]		/* destination */
	ldr	r5, [r0, #4]		/* entry */
	ldr	r6, [r0, #8]		/* payload size */
	ldr	r7, =PAYLOAD_SRC

copy_payload:
	cmp	r6, #0
	beq	jump_payload
	ldrb	r0, [r7], #1
	strb	r0, [r4], #1
	subs	r6, r6, #1
	b	copy_payload

jump_payload:
	mov	r0, #0
	mov	r1, #0
	mov	r2, #0
	bx	r5
