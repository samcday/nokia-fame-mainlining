/* SPDX-License-Identifier: MIT */
/*
 * Tiny ARM32 UART loader for recovering from a prompt-only APPSBL U-Boot.
 *
 * Loaded by U-Boot at STAGE0_LOAD_ADDR with mw.l commands, then started with
 * go. It receives a small little-endian header followed by a raw payload over
 * UARTDM v1.3 and jumps to the requested entry point.
 */

	.syntax unified
	.arm

	.equ STAGE0_STACK, 0x82040000
	.equ UART_BASE, 0x16440000

	.equ UARTDM_SR, 0x08
	.equ UARTDM_CR, 0x10
	.equ UARTDM_TF, 0x70
	.equ UARTDM_RF, 0x70
	.equ UARTDM_IPR, 0x18
	.equ UARTDM_DMRX, 0x34
	.equ UARTDM_RXFS, 0x50
	.equ UARTDM_NCF_TX, 0x40

	.equ UARTDM_SR_RX_READY, (1 << 0)
	.equ UARTDM_SR_TX_READY, (1 << 2)
	.equ UARTDM_SR_TX_EMPTY, (1 << 3)
	.equ UARTDM_CR_RX_ENABLE, (1 << 0)
	.equ UARTDM_CR_TX_ENABLE, (1 << 2)
	.equ UARTDM_CR_CMD_RESET_RX, (1 << 4)
	.equ UARTDM_CR_CMD_RESET_TX, (2 << 4)
	.equ UARTDM_CR_CMD_RESET_ERR, (3 << 4)
	.equ UARTDM_CR_CMD_RESET_STALE_INT, (8 << 4)
	.equ UARTDM_CR_CMD_FORCE_STALE, (4 << 8)
	.equ UARTDM_CR_CMD_STALE_EVENT_ENABLE, (5 << 8)
	.equ UARTDM_DMRX_DEF_VALUE, 0x00ffffff
	.equ UARTDM_IPR_STALE_TIMEOUT_LSB, 0x0f
	.equ UARTDM_RXFS_BUF_SHIFT, 7
	.equ UARTDM_RXFS_BUF_MASK, 7

	.equ MAGIC0, 0x454d4146 /* "FAME" */
	.equ MAGIC1, 0x30475453 /* "STG0" */

	.section .text
	.global _start
	.type _start, %function

_start:
	ldr	sp, =STAGE0_STACK
	bl	uart_init
	ldr	r0, =msg_ready
	bl	puts

	bl	get_word_le
	ldr	r1, =MAGIC0
	cmp	r0, r1
	bne	bad_magic
	bl	get_word_le
	ldr	r1, =MAGIC1
	cmp	r0, r1
	bne	bad_magic

	bl	get_word_le
	mov	r4, r0		/* destination */
	bl	get_word_le
	mov	r5, r0		/* entry */
	bl	get_word_le
	mov	r6, r0		/* size */
	bl	get_word_le
	mov	r7, r0		/* expected byte-sum */
	mov	r8, #0		/* actual byte-sum */

	ldr	r0, =msg_recv
	bl	puts

1:
	cmp	r6, #0
	beq	verify_checksum
	bl	getc
	strb	r0, [r4], #1
	add	r8, r8, r0
	subs	r6, r6, #1
	b	1b

verify_checksum:
	cmp	r8, r7
	bne	bad_checksum
	ldr	r0, =msg_ok
	bl	puts
	bl	tx_drain

	mov	r4, r5
	mov	r0, #0
	mov	r1, r5
	mov	r2, #0xff
	mov	r3, #0xff
	bx	r4

bad_magic:
	ldr	r0, =msg_bad_magic
	bl	puts
	b	.

bad_checksum:
	ldr	r0, =msg_bad_checksum
	bl	puts
	b	.

	.type uart_init, %function
uart_init:
	push	{r0, r1, lr}
	ldr	r0, =UART_BASE
	mov	r1, #0xff
	str	r1, [r0, #0x08]	/* CSR: fixed 115200 value for v1.3 */
	mov	r1, #0x34
	str	r1, [r0, #0x04]	/* MR2: 8n1 */
	mov	r1, #0
	str	r1, [r0, #0x1c]	/* TFWR */
	str	r1, [r0, #0x20]	/* RFWR */
	mov	r1, #UARTDM_IPR_STALE_TIMEOUT_LSB
	str	r1, [r0, #UARTDM_IPR]
	mov	r1, #UARTDM_CR_CMD_RESET_RX
	str	r1, [r0, #UARTDM_CR]
	mov	r1, #UARTDM_CR_CMD_RESET_TX
	str	r1, [r0, #UARTDM_CR]
	mov	r1, #UARTDM_CR_CMD_RESET_ERR
	str	r1, [r0, #UARTDM_CR]
	mov	r1, #UARTDM_CR_RX_ENABLE
	str	r1, [r0, #UARTDM_CR]
	mov	r1, #UARTDM_CR_TX_ENABLE
	str	r1, [r0, #UARTDM_CR]
	bl	reset_stale
	pop	{r0, r1, pc}

	.type reset_stale, %function
reset_stale:
	push	{r0, r1, lr}
	ldr	r0, =UART_BASE
	mov	r1, #UARTDM_CR_CMD_RESET_STALE_INT
	str	r1, [r0, #UARTDM_CR]
	ldr	r1, =UARTDM_DMRX_DEF_VALUE
	str	r1, [r0, #UARTDM_DMRX]
	ldr	r1, =UARTDM_CR_CMD_STALE_EVENT_ENABLE
	str	r1, [r0, #UARTDM_CR]
	pop	{r0, r1, pc}

	.type putc, %function
putc:
	push	{r1, r2, lr}
	ldr	r1, =UART_BASE
1:
	ldr	r2, [r1, #UARTDM_SR]
	tst	r2, #UARTDM_SR_TX_READY
	beq	1b
	mov	r2, #1
	str	r2, [r1, #UARTDM_NCF_TX]
	str	r0, [r1, #UARTDM_TF]
	pop	{r1, r2, pc}

	.type tx_drain, %function
tx_drain:
	push	{r0, r1, lr}
	ldr	r0, =UART_BASE
1:
	ldr	r1, [r0, #UARTDM_SR]
	tst	r1, #UARTDM_SR_TX_EMPTY
	beq	1b
	pop	{r0, r1, pc}

	.type puts, %function
puts:
	push	{r0, r1, lr}
	mov	r1, r0
1:
	ldrb	r0, [r1], #1
	cmp	r0, #0
	beq	2f
	bl	putc
	b	1b
2:
	pop	{r0, r1, pc}

	.type getc, %function
getc:
	push	{r1, r2, r3, r4, r5, lr}
	ldr	r4, =rx_count
	ldr	r5, [r4]
	cmp	r5, #0
	bne	pop_cached

poll_rx:
	ldr	r1, =UART_BASE
	ldr	r2, [r1, #UARTDM_RXFS]
	mov	r3, r2, lsr #UARTDM_RXFS_BUF_SHIFT
	and	r3, r3, #UARTDM_RXFS_BUF_MASK
	cmp	r3, #0
	bne	flush_partial
	ldr	r2, [r1, #UARTDM_SR]
	tst	r2, #UARTDM_SR_RX_READY
	beq	poll_rx
	ldr	r2, [r1, #UARTDM_RF]
	mov	r3, #4
	b	cache_word

flush_partial:
	mov	r2, #UARTDM_CR_CMD_FORCE_STALE
	str	r2, [r1, #UARTDM_CR]
	ldr	r2, [r1, #UARTDM_RF]
	cmp	r3, #4
	movhi	r3, #4
	bl	reset_stale

cache_word:
	ldr	r4, =rx_word
	str	r2, [r4]
	ldr	r4, =rx_count
	str	r3, [r4]

pop_cached:
	ldr	r4, =rx_word
	ldr	r2, [r4]
	and	r0, r2, #0xff
	mov	r2, r2, lsr #8
	str	r2, [r4]
	ldr	r4, =rx_count
	ldr	r3, [r4]
	subs	r3, r3, #1
	str	r3, [r4]
	pop	{r1, r2, r3, r4, r5, pc}

	.type get_word_le, %function
get_word_le:
	push	{r1, r2, r3, r4, lr}
	bl	getc
	mov	r4, r0
	bl	getc
	orr	r4, r4, r0, lsl #8
	bl	getc
	orr	r4, r4, r0, lsl #16
	bl	getc
	orr	r4, r4, r0, lsl #24
	mov	r0, r4
	pop	{r1, r2, r3, r4, pc}

	.align 2
msg_ready:
	.asciz "\r\nFAMESTG0 READY\r\n"
msg_recv:
	.asciz "FAMESTG0 RECV\r\n"
msg_ok:
	.asciz "FAMESTG0 OK JUMP\r\n"
msg_bad_magic:
	.asciz "FAMESTG0 BAD MAGIC\r\n"
msg_bad_checksum:
	.asciz "FAMESTG0 BAD CHECKSUM\r\n"

	.align 2
rx_word:
	.word 0
rx_count:
	.word 0
