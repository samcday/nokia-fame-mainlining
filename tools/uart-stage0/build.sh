#!/usr/bin/env bash
# Build the tiny UART stage0 recovery loader.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OUT_DIR=${OUT_DIR:-"$ROOT_DIR/build"}
CROSS_COMPILE=${CROSS_COMPILE:-arm-none-eabi-}

mkdir -p "$OUT_DIR"

"${CROSS_COMPILE}gcc" \
	-nostdlib \
	-ffreestanding \
	-Wl,-T,"$ROOT_DIR/stage0.ld" \
	-Wl,--build-id=none \
	-Wl,-Map,"$OUT_DIR/stage0.map" \
	-o "$OUT_DIR/stage0.elf" \
	"$ROOT_DIR/stage0.S"

"${CROSS_COMPILE}objcopy" -O binary "$OUT_DIR/stage0.elf" "$OUT_DIR/stage0.bin"
"${CROSS_COMPILE}objdump" -d "$OUT_DIR/stage0.elf" > "$OUT_DIR/stage0.lst"

python3 "$ROOT_DIR/make-uboot-mw.py" \
	--input "$OUT_DIR/stage0.bin" \
	--address 0x82000000 \
	--output "$OUT_DIR/stage0-mw.txt"

sha256sum "$OUT_DIR/stage0.bin"
stat -c 'stage0.bin size: %s bytes' "$OUT_DIR/stage0.bin"
printf 'U-Boot mw script: %s\n' "$OUT_DIR/stage0-mw.txt"
