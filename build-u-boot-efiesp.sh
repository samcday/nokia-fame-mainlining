#!/usr/bin/env bash
# Build a Nokia Fame U-Boot ARM32 EFI-app EFIESP image.

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
Usage: ./build-u-boot-efiesp.sh [KEY=value ...]

Builds U-Boot as a 32-bit ARM EFI application and packages a 64 MiB FAT16
EFIESP image with:

  /efi/boot/bootarm.efi
  /qcom-msm8227-nokia-fame.dtb

Environment overrides:

  U_BOOT_DIR             U-Boot tree path (default: ./u-boot)
  U_BOOT_BUILD_DIR       U-Boot EFI-app build dir (default: ./out/fame/u-boot-efi-arm-app32)
  LINUX_DTB              Fame DTB to place in EFIESP
  OUT_DIR                Output directory (default: ./out/fame/uefi-test)
  DEFCONFIG              U-Boot defconfig (default: efi-arm_app32_defconfig)
  EFIESP_SIZE            EFIESP image size in bytes (default: 67108864)
  EFI_APP_NAME           Copied EFI payload name
  EFIESP_NAME            Output EFIESP image name
  CROSS_COMPILE          ARM GCC cross prefix, e.g. arm-none-eabi-
  JOBS                   make -j value (default: nproc)
  SKIP_UBOOT=1           Reuse existing U-Boot EFI-app artifact

This script only builds files. It does not boot, flash, or erase anything.
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
U_BOOT_DIR=${U_BOOT_DIR:-"$ROOT_DIR/u-boot"}
U_BOOT_BUILD_DIR=${U_BOOT_BUILD_DIR:-"$ROOT_DIR/out/fame/u-boot-efi-arm-app32"}
LINUX_DTB=${LINUX_DTB:-"$ROOT_DIR/out/fame/linux-build/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dtb"}
OUT_DIR=${OUT_DIR:-"$ROOT_DIR/out/fame/uefi-test"}
DEFCONFIG=${DEFCONFIG:-efi-arm_app32_defconfig}
EFIESP_SIZE=${EFIESP_SIZE:-67108864}
EFI_APP_NAME=${EFI_APP_NAME:-u-boot-app-fame-mdp-dump.efi}
EFIESP_NAME=${EFIESP_NAME:-EFIESP-u-boot-fame-mdp-dump.img}
JOBS=${JOBS:-$(nproc)}
SKIP_UBOOT=${SKIP_UBOOT:-0}

EFI_APP="$U_BOOT_BUILD_DIR/u-boot-app.efi"
EFI_APP_OUT="$OUT_DIR/$EFI_APP_NAME"
EFIESP="$OUT_DIR/$EFIESP_NAME"

[[ -d "$U_BOOT_DIR" ]] || die "U-Boot tree not found: $U_BOOT_DIR"
[[ -f "$U_BOOT_DIR/Makefile" ]] || die "U-Boot Makefile not found in: $U_BOOT_DIR"
[[ -f "$U_BOOT_DIR/configs/$DEFCONFIG" ]] || die "U-Boot defconfig not found: $DEFCONFIG"
[[ -f "$LINUX_DTB" ]] || die "missing DTB: $LINUX_DTB"
[[ $((EFIESP_SIZE)) -gt 0 ]] || die "EFIESP_SIZE must be greater than zero"

need make
need mkfs.fat
need mmd
need mcopy
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

mkdir -p "$OUT_DIR" "$U_BOOT_BUILD_DIR"

if [[ "$SKIP_UBOOT" != 1 ]]; then
	printf '==> Using %s\n' "$TOOLCHAIN_DESC"
	printf '==> Configuring U-Boot %s\n' "$DEFCONFIG"
	make -C "$U_BOOT_DIR" O="$U_BOOT_BUILD_DIR" "${MAKE_ARGS[@]}" "$DEFCONFIG"

	printf '==> Building U-Boot ARM EFI application\n'
	make -C "$U_BOOT_DIR" O="$U_BOOT_BUILD_DIR" "${MAKE_ARGS[@]}" -j"$JOBS"
else
	printf '==> SKIP_UBOOT=1: reusing %s\n' "$EFI_APP"
fi

[[ -f "$EFI_APP" ]] || die "missing EFI app: $EFI_APP"

cp "$EFI_APP" "$EFI_APP_OUT"

printf '==> Creating FAT16 EFIESP image\n'
rm -f "$EFIESP"
truncate -s "$EFIESP_SIZE" "$EFIESP"
mkfs.fat -F 16 -n EFIESP "$EFIESP" >/dev/null
MTOOLS_SKIP_CHECK=1 mmd -i "$EFIESP" ::/efi
MTOOLS_SKIP_CHECK=1 mmd -i "$EFIESP" ::/efi/boot
MTOOLS_SKIP_CHECK=1 mcopy -i "$EFIESP" "$EFI_APP_OUT" ::/efi/boot/bootarm.efi
MTOOLS_SKIP_CHECK=1 mcopy -i "$EFIESP" "$LINUX_DTB" ::/qcom-msm8227-nokia-fame.dtb

efi_app_size=$(stat -c%s "$EFI_APP_OUT")
efiesp_size=$(stat -c%s "$EFIESP")
efi_app_sha256=$(sha256sum "$EFI_APP_OUT" | cut -d' ' -f1)
efiesp_sha256=$(sha256sum "$EFIESP" | cut -d' ' -f1)

printf '\n==> Wrote EFIESP artifacts\n'
printf '    EFI app:  %s (%s bytes, sha256 %s)\n' \
	"$EFI_APP_OUT" "$efi_app_size" "$efi_app_sha256"
printf '    DTB:      %s (%s bytes)\n' "$LINUX_DTB" "$(stat -c%s "$LINUX_DTB")"
printf '    EFIESP:   %s (%s bytes, sha256 %s)\n' \
	"$EFIESP" "$efiesp_size" "$efiesp_sha256"

printf '\nGuarded live-device write sequence, only after explicit approval:\n'
printf '  cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true switch flash\n'
printf '  cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --dry-run EFIESP %q\n' "$EFIESP"
printf '  cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --confirm-raw-write EFIESP %q\n' "$EFIESP"
printf '  cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=false reset\n'
