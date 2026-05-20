#!/usr/bin/env bash
# Build an LK-chainable Android boot image containing U-Boot fastboot gadget.

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
Usage: ./build-u-boot-lk-fastboot.sh [KEY=value ...]

Builds the canonical Fame DTB from ./linux, builds U-Boot with the LK-chain
fastboot defconfig, then wraps u-boot-dtb.bin in an Android boot image suitable
for `fastboot boot` from the Android4Lumia LK currently installed in UEFI.

Environment overrides:

  LINUX_DIR             Kernel tree path (default: ./linux)
  U_BOOT_DIR            U-Boot tree path (default: ./u-boot)
  OUT_DIR               Output directory (default: ./out/fame/u-boot-lk-fastboot)
  LINUX_BUILD_DIR       Kernel build directory (default: ./out/fame/linux-build)
  U_BOOT_BUILD_DIR      U-Boot build directory (default: ./out/fame/u-boot-fame-lk-fastboot)
  DEFCONFIG             U-Boot defconfig (default: nokia_fame_lk_fastboot_defconfig)
  DTB                   DTB basename (default: qcom-msm8227-nokia-fame.dtb)
  LINUX_DT_TARGET       Kernel DT build target (default: dtbs)
  CROSS_COMPILE         ARM GCC cross prefix, e.g. arm-none-eabi-
  JOBS                  make -j value (default: nproc)
  BOOT_BASE             Android boot image base (default: 0x80200000)
  BOOT_KERNEL_OFFSET    Kernel/U-Boot offset from base (default: 0x00008000)
  BOOT_RAMDISK_OFFSET   Ramdisk offset from base (default: 0x02000000)
  BOOT_TAGS_OFFSET      ATAGS/DT offset from base (default: 0x00000100)
  BOOT_PAGESIZE         Android boot image page size (default: 4096)
  BOOT_CMDLINE          Header cmdline (default: empty)
  SKIP_LINUX=1          Reuse existing Linux DTB
  SKIP_UBOOT=1          Reuse existing U-Boot build artifact
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
U_BOOT_DIR=${U_BOOT_DIR:-"$ROOT_DIR/u-boot"}
OUT_DIR=${OUT_DIR:-"$ROOT_DIR/out/fame/u-boot-lk-fastboot"}
LINUX_BUILD_DIR=${LINUX_BUILD_DIR:-"$ROOT_DIR/out/fame/linux-build"}
U_BOOT_BUILD_DIR=${U_BOOT_BUILD_DIR:-"$ROOT_DIR/out/fame/u-boot-fame-lk-fastboot"}
DEFCONFIG=${DEFCONFIG:-nokia_fame_lk_fastboot_defconfig}
DTB=${DTB:-qcom-msm8227-nokia-fame.dtb}
LINUX_DT_TARGET=${LINUX_DT_TARGET:-dtbs}
JOBS=${JOBS:-$(nproc)}
BOOT_BASE=${BOOT_BASE:-0x80200000}
BOOT_KERNEL_OFFSET=${BOOT_KERNEL_OFFSET:-0x00008000}
BOOT_RAMDISK_OFFSET=${BOOT_RAMDISK_OFFSET:-0x02000000}
BOOT_TAGS_OFFSET=${BOOT_TAGS_OFFSET:-0x00000100}
BOOT_PAGESIZE=${BOOT_PAGESIZE:-4096}
BOOT_CMDLINE=${BOOT_CMDLINE:-}
SKIP_LINUX=${SKIP_LINUX:-0}
SKIP_UBOOT=${SKIP_UBOOT:-0}

BOOT_KERNEL_ADDR=$(printf '0x%08x' $((BOOT_BASE + BOOT_KERNEL_OFFSET)))
DTB_PATH="$LINUX_BUILD_DIR/arch/arm/boot/dts/qcom/$DTB"
U_BOOT_BIN="$U_BOOT_BUILD_DIR/u-boot-dtb.bin"
IMAGE="$OUT_DIR/u-boot-fame-lk-fastboot.img"

[[ -d "$LINUX_DIR" ]] || die "kernel tree not found: $LINUX_DIR"
[[ -f "$LINUX_DIR/Makefile" ]] || die "kernel Makefile not found in: $LINUX_DIR"
[[ -d "$U_BOOT_DIR" ]] || die "U-Boot tree not found: $U_BOOT_DIR"
[[ -f "$U_BOOT_DIR/Makefile" ]] || die "U-Boot Makefile not found in: $U_BOOT_DIR"
[[ -f "$U_BOOT_DIR/configs/$DEFCONFIG" ]] || die "U-Boot defconfig not found: $DEFCONFIG"

need make
need mkbootimg
need sha256sum
need stat

MAKE_ARGS=(ARCH=arm)
TOOLCHAIN_DESC=none

if [[ -n "${CROSS_COMPILE:-}" ]]; then
	need "${CROSS_COMPILE}gcc"
	MAKE_ARGS+=(CROSS_COMPILE="$CROSS_COMPILE")
	TOOLCHAIN_DESC="GCC ${CROSS_COMPILE}"
else
	for prefix in arm-none-eabi- arm-linux-gnueabi- arm-linux-gnueabihf- arm-linux-gnu-; do
		if have "${prefix}gcc"; then
			CROSS_COMPILE=$prefix
			MAKE_ARGS+=(CROSS_COMPILE="$CROSS_COMPILE")
			TOOLCHAIN_DESC="GCC ${CROSS_COMPILE}"
			break
		fi
	done
fi

[[ "$TOOLCHAIN_DESC" != none ]] || die 'no ARM GCC cross compiler found; set CROSS_COMPILE='

mkdir -p "$OUT_DIR" "$LINUX_BUILD_DIR" "$U_BOOT_BUILD_DIR"

if [[ "$SKIP_LINUX" != 1 ]]; then
	printf '==> Using %s\n' "$TOOLCHAIN_DESC"
	printf '==> Configuring Linux qcom_defconfig\n'
	make -C "$LINUX_DIR" O="$LINUX_BUILD_DIR" "${MAKE_ARGS[@]}" qcom_defconfig

	printf '==> Building Linux %s\n' "$LINUX_DT_TARGET"
	make -C "$LINUX_DIR" O="$LINUX_BUILD_DIR" "${MAKE_ARGS[@]}" -j"$JOBS" "$LINUX_DT_TARGET"
else
	printf '==> SKIP_LINUX=1: reusing %s\n' "$DTB_PATH"
fi

[[ -f "$DTB_PATH" ]] || die "missing DTB: $DTB_PATH"

if [[ "$SKIP_UBOOT" != 1 ]]; then
	printf '==> Configuring U-Boot %s\n' "$DEFCONFIG"
	make -C "$U_BOOT_DIR" O="$U_BOOT_BUILD_DIR" "${MAKE_ARGS[@]}" "$DEFCONFIG"

	printf '==> Building U-Boot with EXT_DTB=%s\n' "$DTB_PATH"
	make -C "$U_BOOT_DIR" O="$U_BOOT_BUILD_DIR" "${MAKE_ARGS[@]}" -j"$JOBS" EXT_DTB="$DTB_PATH"
else
	printf '==> SKIP_UBOOT=1: reusing %s\n' "$U_BOOT_BIN"
fi

[[ -f "$U_BOOT_BIN" ]] || die "missing U-Boot payload: $U_BOOT_BIN"
[[ -f "$U_BOOT_BUILD_DIR/.config" ]] || die "missing U-Boot config: $U_BOOT_BUILD_DIR/.config"

config_text_base=
while IFS='=' read -r key value; do
	if [[ "$key" == CONFIG_TEXT_BASE ]]; then
		config_text_base=$value
		break
	fi
done < "$U_BOOT_BUILD_DIR/.config"
[[ -n "$config_text_base" ]] || die "CONFIG_TEXT_BASE not found in $U_BOOT_BUILD_DIR/.config"
[[ $((BOOT_KERNEL_ADDR)) -eq $((config_text_base)) ]] || \
	die "boot kernel address $BOOT_KERNEL_ADDR does not match U-Boot CONFIG_TEXT_BASE=$config_text_base"

mkbootimg_args=(
	--header_version 0
	--kernel "$U_BOOT_BIN"
	--base "$BOOT_BASE"
	--kernel_offset "$BOOT_KERNEL_OFFSET"
	--ramdisk_offset "$BOOT_RAMDISK_OFFSET"
	--tags_offset "$BOOT_TAGS_OFFSET"
	--pagesize "$BOOT_PAGESIZE"
	--board nokia-fame
	-o "$IMAGE"
)

if [[ -n "$BOOT_CMDLINE" ]]; then
	mkbootimg_args+=(--cmdline "$BOOT_CMDLINE")
fi

printf '==> Packaging Android boot image\n'
mkbootimg "${mkbootimg_args[@]}"

dtb_size=$(stat -c%s "$DTB_PATH")
uboot_size=$(stat -c%s "$U_BOOT_BIN")
image_size=$(stat -c%s "$IMAGE")
image_sha256=$(sha256sum "$IMAGE" | cut -d' ' -f1)

printf '\n==> Wrote LK fastboot artifact\n'
printf '    DTB:       %s (%s bytes)\n' "$DTB_PATH" "$dtb_size"
printf '    U-Boot:    %s (%s bytes)\n' "$U_BOOT_BIN" "$uboot_size"
printf '    boot img:  %s (%s bytes, sha256 %s)\n' "$IMAGE" "$image_size" "$image_sha256"
printf '    base:      %s\n' "$BOOT_BASE"
printf '    kernel:    %s\n' "$BOOT_KERNEL_ADDR"
printf '    tags:      %s\n' "$(printf '0x%08x' $((BOOT_BASE + BOOT_TAGS_OFFSET)))"

printf '\nRun from the working LK fastboot prompt:\n'
printf '  fastboot boot %q\n' "$IMAGE"
