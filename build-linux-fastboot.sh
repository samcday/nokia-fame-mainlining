#!/usr/bin/env bash
# Build a U-Boot-fastboot-bootable Android boot image for mainline Linux.

set -euo pipefail

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

have() {
	command -v "$1" >/dev/null 2>&1
}

need() {
	have "$1" || die "missing required tool: $1"
}

usage() {
	cat <<'EOF'
Usage: ./build-linux-fastboot.sh [KEY=value ...]

Builds ./linux and creates an Android boot.img intended for persistent U-Boot:

  fastboot boot out/fame/fame-linux-fastboot.img

The kernel payload defaults to uncompressed ARM Image for fast boot (U-Boot
skips decompression). Set GZIP=1 to gzip-compress the kernel instead, trading
boot speed for a smaller image. The Fame DTB is stored in the Android
boot-image v2 DTB area so U-Boot can pass it as a normal bootloader-provided
FDT.

Environment overrides:

  LINUX_DIR          Kernel tree path (default: ./linux)
  OUT_DIR            Output directory (default: ./out/fame)
  BUILD_DIR          Kernel build directory (default: $OUT_DIR/linux-build)
  IMAGE              Output boot image path (default: $OUT_DIR/fame-linux-fastboot.img)
  DTB                DTB basename (default: qcom-msm8227-nokia-fame.dtb)
  MINITRD_SCRIPT     mkosi/APK minitrd builder (default: ./build-minitrd.sh)
  CMDLINE            Android boot.img/kernel cmdline
  DTB_OFFSET         Android boot.img DTB load offset (default: 0x08200000)
  CROSS_COMPILE      ARM cross prefix, e.g. arm-none-eabi-
  LLVM               LLVM suffix/prefix for kernel builds, if not using CROSS_COMPILE
  JOBS               make -j value (default: nproc)
  SKIP_BUILD=1       Reuse existing kernel artifacts in BUILD_DIR
  GZIP=1             Gzip-compress the kernel before passing to mkbootimg

Boot image layout defaults follow the Fame Android/pmaports base while keeping
FDT and ramdisk above the first 128 MiB of RAM, away from decompressor output
and low-memory scratch areas:

	base=0x80200000 kernel_offset=0x00008000 tags_offset=0x02000000
	dtb_offset=0x08200000 ramdisk_offset=0x08400000 pagesize=4096 header_version=2
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

for arg in "$@"; do
	if [[ "$arg" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
		declare -gx "$arg"
	else
		die "unknown argument: $arg"
	fi
done

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LINUX_DIR=${LINUX_DIR:-"$ROOT_DIR/linux"}
OUT_DIR=${OUT_DIR:-"$ROOT_DIR/out/fame"}
BUILD_DIR=${BUILD_DIR:-"$OUT_DIR/linux-build"}
IMAGE=${IMAGE:-"$OUT_DIR/fame-linux-fastboot.img"}
DTB=${DTB:-qcom-msm8227-nokia-fame.dtb}
JOBS=${JOBS:-$(nproc)}
SKIP_BUILD=${SKIP_BUILD:-0}
MINITRD_SCRIPT=${MINITRD_SCRIPT:-"$ROOT_DIR/build-minitrd.sh"}
MINITRD=${MINITRD:-"$OUT_DIR/minitrd.cpio.gz"}

KERNEL_OFFSET=${KERNEL_OFFSET:-0x00008000}
RAMDISK_OFFSET=${RAMDISK_OFFSET:-0x08400000}
TAGS_OFFSET=${TAGS_OFFSET:-0x02000000}
DTB_OFFSET=${DTB_OFFSET:-0x08200000}
BOOT_BASE=${BOOT_BASE:-0x80200000}
BOOT_PAGESIZE=${BOOT_PAGESIZE:-4096}

DEFAULT_CMDLINE='console=ttyMSM0,115200n8 earlycon loglevel=8 ignore_loglevel panic=5 rdinit=/init'
CMDLINE=${CMDLINE:-$DEFAULT_CMDLINE}

[[ -d "$LINUX_DIR" ]] || die "kernel tree not found: $LINUX_DIR"
[[ -f "$LINUX_DIR/Makefile" ]] || die "kernel Makefile not found in: $LINUX_DIR"

need make
need gzip
need mkbootimg
need stat

mkdir -p "$OUT_DIR" "$BUILD_DIR"

[[ -x "$MINITRD_SCRIPT" ]] || die "minitrd builder not executable: $MINITRD_SCRIPT"
"$MINITRD_SCRIPT" \
	OUTPUT="$MINITRD" \
	OUT_DIR="$OUT_DIR"

[[ -f "$MINITRD" ]] || die "minitrd not found: $MINITRD"

MAKE_ARGS=(ARCH=arm)
TOOLCHAIN_DESC='none'

if [[ "$SKIP_BUILD" != 1 ]]; then
	if [[ -n "${CROSS_COMPILE:-}" ]]; then
		need "${CROSS_COMPILE}gcc"
		MAKE_ARGS+=(CROSS_COMPILE="$CROSS_COMPILE")
		TOOLCHAIN_DESC="GCC ${CROSS_COMPILE}"
	else
		for prefix in arm-linux-gnueabi- arm-linux-gnueabihf- arm-linux-gnu- arm-none-eabi-; do
			if have "${prefix}gcc"; then
				CROSS_COMPILE=$prefix
				MAKE_ARGS+=(CROSS_COMPILE="$CROSS_COMPILE")
				TOOLCHAIN_DESC="GCC ${CROSS_COMPILE}"
				break
			fi
		done
	fi

	if [[ "$TOOLCHAIN_DESC" == none ]]; then
		if [[ -n "${LLVM:-}" ]]; then
			MAKE_ARGS+=(LLVM="$LLVM" LLVM_IAS="${LLVM_IAS:-1}")
			TOOLCHAIN_DESC="LLVM ${LLVM}"
		elif have clang && have ld.lld; then
			MAKE_ARGS+=(LLVM=1 LLVM_IAS="${LLVM_IAS:-1}")
			TOOLCHAIN_DESC='LLVM'
		else
			die 'no ARM GCC cross compiler found and LLVM toolchain is incomplete; set CROSS_COMPILE= or LLVM='
		fi
	fi
fi

if [[ "$SKIP_BUILD" != 1 ]]; then
	printf '==> Using %s\n' "$TOOLCHAIN_DESC"
	printf '==> Configuring qcom_defconfig\n'
	make -C "$LINUX_DIR" O="$BUILD_DIR" "${MAKE_ARGS[@]}" qcom_defconfig

	printf '==> Building Image and dtbs\n'
	make -C "$LINUX_DIR" O="$BUILD_DIR" "${MAKE_ARGS[@]}" -j"$JOBS" Image dtbs
else
	printf '==> SKIP_BUILD=1: reusing artifacts from %s\n' "$BUILD_DIR"
fi

RAW_IMAGE="$BUILD_DIR/arch/arm/boot/Image"
DTB_PATH="$BUILD_DIR/arch/arm/boot/dts/qcom/$DTB"
GZIP=${GZIP:-0}

[[ -f "$RAW_IMAGE" ]] || die "missing Image: $RAW_IMAGE"
[[ -f "$DTB_PATH" ]] || die "missing DTB: $DTB_PATH"

if [[ "$GZIP" = 1 ]]; then
	KERNEL_IMAGE="$OUT_DIR/Image.gz"
	gzip -n -c "$RAW_IMAGE" > "$KERNEL_IMAGE"
	chmod 0644 "$KERNEL_IMAGE"
else
	KERNEL_IMAGE="$RAW_IMAGE"
fi

printf '==> Creating Android boot image\n'
mkbootimg \
	--kernel "$KERNEL_IMAGE" \
	--ramdisk "$MINITRD" \
	--dtb "$DTB_PATH" \
	--base "$BOOT_BASE" \
	--kernel_offset "$KERNEL_OFFSET" \
	--ramdisk_offset "$RAMDISK_OFFSET" \
	--tags_offset "$TAGS_OFFSET" \
	--dtb_offset "$DTB_OFFSET" \
	--pagesize "$BOOT_PAGESIZE" \
	--header_version 2 \
	--cmdline "$CMDLINE" \
	--output "$IMAGE"

image_size=$(stat -c%s "$IMAGE")
kernel_size=$(stat -c%s "$KERNEL_IMAGE")
ramdisk_size=$(stat -c%s "$MINITRD")
dtb_size=$(stat -c%s "$DTB_PATH")

printf '\n==> Wrote %s\n' "$IMAGE"
printf '    kernel:    %s (%s bytes)\n' "$KERNEL_IMAGE" "$kernel_size"
printf '    ramdisk:   %s (%s bytes)\n' "$MINITRD" "$ramdisk_size"
printf '    dtb:       %s (%s bytes)\n' "$DTB_PATH" "$dtb_size"
printf '    image:     %s bytes\n' "$image_size"
printf '    DTB:       %s\n' "$DTB"
printf '    cmdline:   %s\n' "$CMDLINE"
printf '    layout:    base=%s kernel_offset=%s ramdisk_offset=%s tags_offset=%s dtb_offset=%s pagesize=%s header_version=2\n' \
	"$BOOT_BASE" "$KERNEL_OFFSET" "$RAMDISK_OFFSET" "$TAGS_OFFSET" "$DTB_OFFSET" "$BOOT_PAGESIZE"
printf '\nBoot with persistent U-Boot fastboot:\n'
printf '  fastboot boot %q\n' "$IMAGE"
