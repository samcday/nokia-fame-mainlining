#!/usr/bin/env bash
# Build Nokia Fame U-Boot payloads for volatile boot and persistent UEFI flash.

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
Usage: ./build-u-boot.sh [KEY=value ...]

Builds the canonical Fame DTB, builds position-independent APPSBL U-Boot, then
packages the same u-boot-dtb.bin as:

  1. an Android boot image for non-flashing `fastboot boot`
  2. a Qualcomm appsbl-style MBN for persistent `fastboot flash UEFI`
  3. a full UEFI partition image for FlashApp/lp-externals raw writes

Environment overrides:

  LINUX_DIR             Kernel tree path (default: ./linux)
  U_BOOT_DIR            U-Boot tree path (default: ./u-boot)
  OUT_DIR               Output directory (default: ./out/fame/u-boot)
  LINUX_BUILD_DIR       Kernel build directory (default: ./out/fame/linux-build)
  U_BOOT_BUILD_DIR      U-Boot build directory (default: ./out/fame/u-boot-build)
  DEFCONFIG             U-Boot defconfig (default: nokia_fame_appsbl_pie_defconfig)
  DTB                   DTB basename (default: qcom-msm8227-nokia-fame.dtb)
  LINUX_DT_TARGET       Kernel DT build target (default: dtbs)
  CROSS_COMPILE         ARM GCC cross prefix, e.g. arm-none-eabi-
  JOBS                  make -j value (default: nproc)
  TEXT_BASE             APPSBL MBN load address (default: 0x88F00000)
  FASTBOOT_BUF_ADDR     Runtime fastboot download buffer (default: 0x82000000)
  BOOT_IMAGE_BASE       Android boot image base (default: FASTBOOT_BUF_ADDR)
  BOOT_IMAGE_KERNEL_OFFSET Android kernel offset / U-Boot entry offset (default: 0x00001000)
  BOOT_IMAGE_PAGESIZE   Android boot image page size (default: 4096)
  BOOT_IMAGE_HEADER_VERSION Android boot image header version (default: 0)
  BOOT_IMAGE_NAME       `fastboot boot` image (default: u-boot-fame-fastboot.img)
  UEFI_MBN_NAME         `fastboot flash UEFI` MBN (default: u-boot-fame-uefi.mbn)
  UEFI_RAW_NAME         Raw UEFI partition image (default: UEFI-u-boot-fame-uefi.bin)
  MBN_PAYLOAD_ALIGN     Payload alignment in the APPSBL header (default: 8)
  FASTBOOT_FLASH_ALIGN  Output MBN file alignment for block flash (default: 512)
  UEFI_PARTITION_SIZE   Raw UEFI partition image size in bytes (default: 2560000)
  SKIP_LINUX=1          Reuse existing Linux DTB
  SKIP_UBOOT=1          Reuse existing U-Boot build artifact

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
LINUX_DIR=${LINUX_DIR:-"$ROOT_DIR/linux"}
U_BOOT_DIR=${U_BOOT_DIR:-"$ROOT_DIR/u-boot"}
OUT_DIR=${OUT_DIR:-"$ROOT_DIR/out/fame/u-boot"}
LINUX_BUILD_DIR=${LINUX_BUILD_DIR:-"$ROOT_DIR/out/fame/linux-build"}
U_BOOT_BUILD_DIR=${U_BOOT_BUILD_DIR:-"$ROOT_DIR/out/fame/u-boot-build"}
DEFCONFIG=${DEFCONFIG:-nokia_fame_appsbl_pie_defconfig}
DTB=${DTB:-qcom-msm8227-nokia-fame.dtb}
LINUX_DT_TARGET=${LINUX_DT_TARGET:-dtbs}
JOBS=${JOBS:-$(nproc)}
TEXT_BASE=${TEXT_BASE:-0x88F00000}
FASTBOOT_BUF_ADDR=${FASTBOOT_BUF_ADDR:-0x82000000}
BOOT_IMAGE_BASE=${BOOT_IMAGE_BASE:-$FASTBOOT_BUF_ADDR}
BOOT_IMAGE_KERNEL_OFFSET=${BOOT_IMAGE_KERNEL_OFFSET:-0x00001000}
BOOT_IMAGE_PAGESIZE=${BOOT_IMAGE_PAGESIZE:-4096}
BOOT_IMAGE_HEADER_VERSION=${BOOT_IMAGE_HEADER_VERSION:-0}
BOOT_IMAGE_NAME=${BOOT_IMAGE_NAME:-u-boot-fame-fastboot.img}
UEFI_MBN_NAME=${UEFI_MBN_NAME:-u-boot-fame-uefi.mbn}
UEFI_RAW_NAME=${UEFI_RAW_NAME:-UEFI-u-boot-fame-uefi.bin}
MBN_PAYLOAD_ALIGN=${MBN_PAYLOAD_ALIGN:-8}
FASTBOOT_FLASH_ALIGN=${FASTBOOT_FLASH_ALIGN:-512}
UEFI_PARTITION_SIZE=${UEFI_PARTITION_SIZE:-2560000}
SKIP_LINUX=${SKIP_LINUX:-0}
SKIP_UBOOT=${SKIP_UBOOT:-0}

DTB_PATH="$LINUX_BUILD_DIR/arch/arm/boot/dts/qcom/$DTB"
U_BOOT_BIN="$U_BOOT_BUILD_DIR/u-boot-dtb.bin"
BOOT_IMAGE="$OUT_DIR/$BOOT_IMAGE_NAME"
UEFI_MBN="$OUT_DIR/$UEFI_MBN_NAME"
UEFI_RAW="$OUT_DIR/$UEFI_RAW_NAME"

[[ -d "$LINUX_DIR" ]] || die "kernel tree not found: $LINUX_DIR"
[[ -f "$LINUX_DIR/Makefile" ]] || die "kernel Makefile not found in: $LINUX_DIR"
[[ -d "$U_BOOT_DIR" ]] || die "U-Boot tree not found: $U_BOOT_DIR"
[[ -f "$U_BOOT_DIR/Makefile" ]] || die "U-Boot Makefile not found in: $U_BOOT_DIR"
[[ -f "$U_BOOT_DIR/configs/$DEFCONFIG" ]] || die "U-Boot defconfig not found: $DEFCONFIG"

need make
need perl
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
[[ $((BOOT_IMAGE_PAGESIZE)) -gt 0 ]] || die "BOOT_IMAGE_PAGESIZE must be greater than zero"
[[ $((MBN_PAYLOAD_ALIGN)) -gt 0 ]] || die "MBN_PAYLOAD_ALIGN must be greater than zero"
[[ $((FASTBOOT_FLASH_ALIGN)) -gt 0 ]] || die "FASTBOOT_FLASH_ALIGN must be greater than zero"
[[ $((UEFI_PARTITION_SIZE)) -gt 0 ]] || die "UEFI_PARTITION_SIZE must be greater than zero"
BOOT_IMAGE_ENTRY_ADDR=$(printf '0x%08x' $((BOOT_IMAGE_BASE + BOOT_IMAGE_KERNEL_OFFSET)))

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

printf '==> Packaging Android boot image for volatile U-Boot fastboot boot\n'
mkbootimg \
	--kernel "$U_BOOT_BIN" \
	--base "$BOOT_IMAGE_BASE" \
	--kernel_offset "$BOOT_IMAGE_KERNEL_OFFSET" \
	--pagesize "$BOOT_IMAGE_PAGESIZE" \
	--header_version "$BOOT_IMAGE_HEADER_VERSION" \
	--cmdline '' \
	--output "$BOOT_IMAGE"

printf '==> Packaging Qualcomm appsbl-style MBN and raw UEFI image\n'
perl -e '
use strict;
use warnings;

my ($payload, $mbn, $raw, $base_arg, $payload_align_arg, $file_align_arg, $part_size_arg) = @ARGV;
my $base = $base_arg =~ /^0x/i ? hex($base_arg) : int($base_arg);
my $payload_align = int($payload_align_arg);
my $file_align = int($file_align_arg);
my $part_size = int($part_size_arg);
my $payload_size = -s $payload;
die "missing payload\n" unless defined $payload_size;
die "invalid payload alignment\n" unless $payload_align > 0;
die "invalid file alignment\n" unless $file_align > 0;
die "invalid partition size\n" unless $part_size > 0;

my $aligned_payload_size = int(($payload_size + $payload_align - 1) / $payload_align) * $payload_align;
my $payload_pad = $aligned_payload_size - $payload_size;
my $mbn_payload_size = 40 + $aligned_payload_size;
my $aligned_file_size = int(($mbn_payload_size + $file_align - 1) / $file_align) * $file_align;
my $file_pad = $aligned_file_size - $mbn_payload_size;
die "MBN size $aligned_file_size exceeds partition size $part_size\n" if $aligned_file_size > $part_size;
my $raw_pad = $part_size - $aligned_file_size;

my $header = pack("V10",
	0x00000005,
	0x00000003,
	0x00000000,
	$base,
	$aligned_payload_size,
	$aligned_payload_size,
	$base + $aligned_payload_size,
	0x00000000,
	$base + $aligned_payload_size,
	0x00000000,
);

open my $in, "<:raw", $payload or die "open $payload: $!\n";
open my $out, ">:raw", $mbn or die "open $mbn: $!\n";
open my $raw_out, ">:raw", $raw or die "open $raw: $!\n";
print {$out} $header or die "write $mbn: $!\n";
print {$raw_out} $header or die "write $raw: $!\n";
while (1) {
	my $buf;
	my $n = read($in, $buf, 1024 * 1024);
	die "read $payload: $!\n" unless defined $n;
	last if $n == 0;
	print {$out} $buf or die "write $mbn: $!\n";
	print {$raw_out} $buf or die "write $raw: $!\n";
}

if ($payload_pad) {
	my $pad = "\0" x $payload_pad;
	print {$out} $pad or die "pad payload in $mbn: $!\n";
	print {$raw_out} $pad or die "pad payload in $raw: $!\n";
}

if ($file_pad) {
	my $pad = "\0" x $file_pad;
	print {$out} $pad or die "pad $mbn: $!\n";
	print {$raw_out} $pad or die "pad $raw: $!\n";
}
close $out or die "close $mbn: $!\n";

if ($raw_pad) {
	my $zeroes = "\0" x (1024 * 1024);
	while ($raw_pad > 0) {
		my $n = $raw_pad < length($zeroes) ? $raw_pad : length($zeroes);
		print {$raw_out} substr($zeroes, 0, $n) or die "pad $raw: $!\n";
		$raw_pad -= $n;
	}
}
close $raw_out or die "close $raw: $!\n";
close $in or die "close $payload: $!\n";
' "$U_BOOT_BIN" "$UEFI_MBN" "$UEFI_RAW" "$TEXT_BASE" "$MBN_PAYLOAD_ALIGN" \
	"$FASTBOOT_FLASH_ALIGN" "$UEFI_PARTITION_SIZE"

dtb_size=$(stat -c%s "$DTB_PATH")
uboot_size=$(stat -c%s "$U_BOOT_BIN")
boot_image_size=$(stat -c%s "$BOOT_IMAGE")
uefi_mbn_size=$(stat -c%s "$UEFI_MBN")
uefi_raw_size=$(stat -c%s "$UEFI_RAW")
aligned_payload_size=$(( (uboot_size + MBN_PAYLOAD_ALIGN - 1) / MBN_PAYLOAD_ALIGN * MBN_PAYLOAD_ALIGN ))
payload_pad=$(( aligned_payload_size - uboot_size ))
mbn_body_size=$(( 40 + aligned_payload_size ))
fastboot_pad=$(( uefi_mbn_size - mbn_body_size ))
partition_pad=$(( uefi_raw_size - uefi_mbn_size ))
boot_image_sha256=$(sha256sum "$BOOT_IMAGE" | cut -d' ' -f1)
uefi_mbn_sha256=$(sha256sum "$UEFI_MBN" | cut -d' ' -f1)
uefi_raw_sha256=$(sha256sum "$UEFI_RAW" | cut -d' ' -f1)

printf '\n==> Wrote U-Boot artifacts\n'
printf '    DTB:          %s (%s bytes)\n' "$DTB_PATH" "$dtb_size"
printf '    U-Boot:       %s (%s bytes)\n' "$U_BOOT_BIN" "$uboot_size"
printf '    boot image:   %s (%s bytes, sha256 %s)\n' "$BOOT_IMAGE" "$boot_image_size" "$boot_image_sha256"
printf '    UEFI MBN:     %s (%s bytes, sha256 %s)\n' "$UEFI_MBN" "$uefi_mbn_size" "$uefi_mbn_sha256"
printf '    UEFI raw:     %s (%s bytes, sha256 %s)\n' "$UEFI_RAW" "$uefi_raw_size" "$uefi_raw_sha256"
printf '    boot layout:  base=%s kernel_offset=%s pagesize=%s header_version=%s\n' \
	"$BOOT_IMAGE_BASE" "$BOOT_IMAGE_KERNEL_OFFSET" "$BOOT_IMAGE_PAGESIZE" "$BOOT_IMAGE_HEADER_VERSION"
printf '    MBN payload:  %s bytes aligned to %s bytes (%s pad bytes)\n' \
	"$aligned_payload_size" "$MBN_PAYLOAD_ALIGN" "$payload_pad"
printf '    flash pad:    %s bytes to %s-byte fastboot block alignment\n' \
	"$fastboot_pad" "$FASTBOOT_FLASH_ALIGN"
printf '    raw pad:      %s bytes to UEFI partition size %s\n' \
	"$partition_pad" "$UEFI_PARTITION_SIZE"
printf '    APPSBL load:  %s\n' "$TEXT_BASE"
printf '    boot buffer:  %s\n' "$FASTBOOT_BUF_ADDR"
printf '    boot entry:   %s\n' "$BOOT_IMAGE_ENTRY_ADDR"

printf '\nVolatile non-flashing test from persistent U-Boot fastboot:\n'
printf "  fastboot -s <fame-serial> oem 'run:setenv fastboot_bootcmd abootimg addr %s\\; bootm start %s\\; bootm loados\\; go %s'\n" \
	"$FASTBOOT_BUF_ADDR" \
	"$FASTBOOT_BUF_ADDR" "$BOOT_IMAGE_ENTRY_ADDR"
printf '  fastboot -s <fame-serial> boot %q\n' "$BOOT_IMAGE"

printf '\nPersistent UEFI update from U-Boot fastboot, only after explicit approval:\n'
printf '  fastboot -s <fame-serial> flash UEFI %q\n' "$UEFI_MBN"
printf "  fastboot -s <fame-serial> oem 'run:reset'\n"

printf '\nPersistent UEFI raw write from FlashApp/lp-externals, only after explicit approval:\n'
printf '  lp-externals flash raw-write-partition --dry-run UEFI %q\n' "$UEFI_RAW"
printf '  lp-externals flash raw-write-partition --confirm-raw-write UEFI %q\n' "$UEFI_RAW"
