#!/usr/bin/env bash
# Build a raw U-Boot UART smoke image for the Lumia 520 UEFI partition.

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
Usage: ./build-u-boot-uefi-smoke.sh [KEY=value ...]

Builds the canonical Fame DTB from ./linux, builds raw ARM32 U-Boot with that
DTB via EXT_DTB, then packages u-boot-dtb.bin as a Qualcomm appsbl-style MBN
padded to the stock UEFI partition size. This script does not flash anything.

Environment overrides:

  LINUX_DIR             Kernel tree path (default: ./linux)
  U_BOOT_DIR            U-Boot tree path (default: ./u-boot)
  OUT_DIR               Output directory (default: ./out/fame/u-boot-uefi-smoke)
  LINUX_BUILD_DIR       Kernel build directory (default: ./out/fame/linux-build)
  U_BOOT_BUILD_DIR      U-Boot build directory (default: ./out/fame/u-boot-fame-smoke)
  DEFCONFIG             U-Boot defconfig (default: nokia_fame_defconfig)
  DTB                   DTB basename (default: qcom-msm8227-nokia-fame.dtb)
  LINUX_DT_TARGET       Kernel DT build target (default: dtbs)
  CROSS_COMPILE         ARM GCC cross prefix, e.g. arm-none-eabi-
  JOBS                  make -j value (default: nproc)
  TEXT_BASE             MBN load address, must match U-Boot TEXT_BASE (default: 0x88F00000)
  MBN_PAYLOAD_ALIGN     Pad payload bytes before MBN sizing (default: 8)
  UEFI_PARTITION_SIZE   Padded output size in bytes (default: 2560000)
  SKIP_LINUX=1          Reuse existing Linux DTB
  SKIP_UBOOT=1          Reuse existing U-Boot build artifact

The padded image is a candidate for the raw GPT partition named UEFI, not EFIESP.
Only flash it after an explicit, current-turn approval and a dry-run succeeds.
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
OUT_DIR=${OUT_DIR:-"$ROOT_DIR/out/fame/u-boot-uefi-smoke"}
LINUX_BUILD_DIR=${LINUX_BUILD_DIR:-"$ROOT_DIR/out/fame/linux-build"}
U_BOOT_BUILD_DIR=${U_BOOT_BUILD_DIR:-"$ROOT_DIR/out/fame/u-boot-fame-smoke"}
DEFCONFIG=${DEFCONFIG:-nokia_fame_defconfig}
DTB=${DTB:-qcom-msm8227-nokia-fame.dtb}
LINUX_DT_TARGET=${LINUX_DT_TARGET:-dtbs}
JOBS=${JOBS:-$(nproc)}
TEXT_BASE=${TEXT_BASE:-0x88F00000}
MBN_PAYLOAD_ALIGN=${MBN_PAYLOAD_ALIGN:-8}
UEFI_PARTITION_SIZE=${UEFI_PARTITION_SIZE:-2560000}
SKIP_LINUX=${SKIP_LINUX:-0}
SKIP_UBOOT=${SKIP_UBOOT:-0}

DTB_PATH="$LINUX_BUILD_DIR/arch/arm/boot/dts/qcom/$DTB"
U_BOOT_BIN="$U_BOOT_BUILD_DIR/u-boot-dtb.bin"
MBN="$OUT_DIR/u-boot-fame-uart-smoke.mbn"
IMAGE="$OUT_DIR/UEFI-u-boot-fame-uart-smoke.bin"

[[ -d "$LINUX_DIR" ]] || die "kernel tree not found: $LINUX_DIR"
[[ -f "$LINUX_DIR/Makefile" ]] || die "kernel Makefile not found in: $LINUX_DIR"
[[ -d "$U_BOOT_DIR" ]] || die "U-Boot tree not found: $U_BOOT_DIR"
[[ -f "$U_BOOT_DIR/Makefile" ]] || die "U-Boot Makefile not found in: $U_BOOT_DIR"
[[ -f "$U_BOOT_DIR/configs/$DEFCONFIG" ]] || die "U-Boot defconfig not found: $DEFCONFIG"

need make
need perl
need stat
need sha256sum

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
[[ $((TEXT_BASE)) -eq $((config_text_base)) ]] || \
	die "TEXT_BASE=$TEXT_BASE does not match U-Boot CONFIG_TEXT_BASE=$config_text_base"
[[ $((MBN_PAYLOAD_ALIGN)) -gt 0 ]] || die "MBN_PAYLOAD_ALIGN must be greater than zero"

printf '==> Packaging Qualcomm appsbl-style MBN and padded UEFI image\n'
perl -e '
use strict;
use warnings;

my ($payload, $mbn, $image, $base_arg, $align_arg, $part_size_arg) = @ARGV;
my $base = $base_arg =~ /^0x/i ? hex($base_arg) : int($base_arg);
my $align = int($align_arg);
my $part_size = int($part_size_arg);
my $payload_size = -s $payload;
die "missing payload\n" unless defined $payload_size;
die "invalid payload alignment\n" unless $align > 0;
my $aligned_size = int(($payload_size + $align - 1) / $align) * $align;
my $payload_pad = $aligned_size - $payload_size;

my $header = pack("V10",
	0x00000005,
	0x00000003,
	0x00000000,
	$base,
	$aligned_size,
	$aligned_size,
	$base + $aligned_size,
	0x00000000,
	$base + $aligned_size,
	0x00000000,
);

open my $in, "<:raw", $payload or die "open $payload: $!\n";
open my $out, ">:raw", $mbn or die "open $mbn: $!\n";
print {$out} $header or die "write $mbn: $!\n";
while (1) {
	my $buf;
	my $n = read($in, $buf, 1024 * 1024);
	die "read $payload: $!\n" unless defined $n;
	last if $n == 0;
	print {$out} $buf or die "write $mbn: $!\n";
}
print {$out} "\0" x $payload_pad or die "pad payload in $mbn: $!\n" if $payload_pad;
close $out or die "close $mbn: $!\n";
close $in or die "close $payload: $!\n";

my $mbn_size = -s $mbn;
die "MBN size $mbn_size exceeds partition size $part_size\n" if $mbn_size > $part_size;

open my $mbn_in, "<:raw", $mbn or die "open $mbn: $!\n";
open my $img_out, ">:raw", $image or die "open $image: $!\n";
while (1) {
	my $buf;
	my $n = read($mbn_in, $buf, 1024 * 1024);
	die "read $mbn: $!\n" unless defined $n;
	last if $n == 0;
	print {$img_out} $buf or die "write $image: $!\n";
}
my $pad = $part_size - $mbn_size;
my $zeros = "\0" x 4096;
while ($pad > 0) {
	my $chunk = $pad > length($zeros) ? length($zeros) : $pad;
	print {$img_out} substr($zeros, 0, $chunk) or die "pad $image: $!\n";
	$pad -= $chunk;
}
close $img_out or die "close $image: $!\n";
close $mbn_in or die "close $mbn: $!\n";
' "$U_BOOT_BIN" "$MBN" "$IMAGE" "$TEXT_BASE" "$MBN_PAYLOAD_ALIGN" "$UEFI_PARTITION_SIZE"

dtb_size=$(stat -c%s "$DTB_PATH")
uboot_size=$(stat -c%s "$U_BOOT_BIN")
mbn_size=$(stat -c%s "$MBN")
image_size=$(stat -c%s "$IMAGE")
aligned_payload_size=$(( (uboot_size + MBN_PAYLOAD_ALIGN - 1) / MBN_PAYLOAD_ALIGN * MBN_PAYLOAD_ALIGN ))
payload_pad=$(( aligned_payload_size - uboot_size ))
image_sha256=$(sha256sum "$IMAGE" | cut -d' ' -f1)
mbn_sha256=$(sha256sum "$MBN" | cut -d' ' -f1)

printf '\n==> Wrote UART smoke artifacts\n'
printf '    DTB:       %s (%s bytes)\n' "$DTB_PATH" "$dtb_size"
printf '    U-Boot:    %s (%s bytes)\n' "$U_BOOT_BIN" "$uboot_size"
printf '    payload:   %s bytes aligned to %s bytes (%s pad bytes)\n' "$aligned_payload_size" "$MBN_PAYLOAD_ALIGN" "$payload_pad"
printf '    MBN:       %s (%s bytes, sha256 %s)\n' "$MBN" "$mbn_size" "$mbn_sha256"
printf '    UEFI img:  %s (%s bytes, sha256 %s)\n' "$IMAGE" "$image_size" "$image_sha256"
printf '    load addr: %s\n' "$TEXT_BASE"

printf '\nGuarded live-device sequence, only after explicit approval:\n'
printf '  cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true switch flash\n'
printf '  cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --dry-run UEFI %q\n' "$IMAGE"
printf '  cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --confirm-raw-write UEFI %q\n' "$IMAGE"
printf '  cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=false reset\n'
