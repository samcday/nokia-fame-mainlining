#!/usr/bin/env bash
# Build raw APPSBL U-Boot fastboot and an LK-chain sanity-test wrapper.

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
Usage: ./build-u-boot-appsbl-fastboot.sh [KEY=value ...]

Builds the canonical Fame DTB, builds raw APPSBL U-Boot fastboot, packages it
as a Qualcomm appsbl-style MBN padded to the stock UEFI partition size, then
wraps the same U-Boot binary in an Android boot image for one-shot `fastboot
boot` sanity testing from the LK currently installed in UEFI.

Environment overrides:

  LINUX_DIR             Kernel tree path (default: ./linux)
  U_BOOT_DIR            U-Boot tree path (default: ./u-boot)
  OUT_DIR               Output directory (default: ./out/fame/u-boot-appsbl-fastboot)
  LINUX_BUILD_DIR       Kernel build directory (default: ./out/fame/linux-build)
  U_BOOT_BUILD_DIR      U-Boot build directory (default: ./out/fame/u-boot-fame-appsbl-fastboot)
  DEFCONFIG             U-Boot defconfig (default: nokia_fame_appsbl_defconfig)
  DTB                   DTB basename (default: qcom-msm8227-nokia-fame.dtb)
  LINUX_DT_TARGET       Kernel DT build target (default: dtbs)
  CROSS_COMPILE         ARM GCC cross prefix, e.g. arm-none-eabi-
  JOBS                  make -j value (default: nproc)
  TEXT_BASE             APPSBL/U-Boot load address (default: 0x88F00000)
  BOOT_BASE             LK wrapper base (default: 0x80200000)
  BOOT_KERNEL_OFFSET    LK wrapper trampoline offset (default: 0x00008000)
  BOOT_RAMDISK_OFFSET   LK wrapper ramdisk offset (default: 0x02000000)
  BOOT_TAGS_OFFSET      LK wrapper tags offset (default: 0x00000100)
  BOOT_PAGESIZE         LK wrapper page size (default: 4096)
  BOOT_CMDLINE          LK wrapper header cmdline (default: empty)
  TRAMPOLINE_SRC        Trampoline source (default: ./tools/lk-trampoline/trampoline.S)
  TRAMPOLINE_BUILD_DIR  Trampoline build directory (default: OUT_DIR/lk-trampoline-build)
  TRAMPOLINE_META_OFFSET Metadata offset inside wrapper kernel (default: 0x00000ff0)
  TRAMPOLINE_PAYLOAD_OFFSET Payload offset inside wrapper kernel (default: 0x00001000)
  TRAMPOLINE_STACK      Temporary trampoline stack (default: 0x82000000)
  MBN_PAYLOAD_ALIGN     Pad payload bytes before MBN sizing (default: 8)
  UEFI_PARTITION_SIZE   Padded UEFI output size in bytes (default: 2560000)
  APPSBL_ARTIFACT_NAME  MBN basename (default: u-boot-fame-appsbl-fastboot)
  UEFI_IMAGE_NAME       Padded output filename (default: UEFI-u-boot-fame-appsbl-fastboot.bin)
  LK_TEST_IMAGE_NAME    LK test image filename (default: u-boot-fame-appsbl-fastboot-lk-trampoline.img)
  SKIP_LINUX=1          Reuse existing Linux DTB
  SKIP_UBOOT=1          Reuse existing U-Boot build artifact

This script does not flash anything.
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
OUT_DIR=${OUT_DIR:-"$ROOT_DIR/out/fame/u-boot-appsbl-fastboot"}
LINUX_BUILD_DIR=${LINUX_BUILD_DIR:-"$ROOT_DIR/out/fame/linux-build"}
U_BOOT_BUILD_DIR=${U_BOOT_BUILD_DIR:-"$ROOT_DIR/out/fame/u-boot-fame-appsbl-fastboot"}
DEFCONFIG=${DEFCONFIG:-nokia_fame_appsbl_defconfig}
DTB=${DTB:-qcom-msm8227-nokia-fame.dtb}
LINUX_DT_TARGET=${LINUX_DT_TARGET:-dtbs}
JOBS=${JOBS:-$(nproc)}
TEXT_BASE=${TEXT_BASE:-0x88F00000}
BOOT_BASE=${BOOT_BASE:-0x80200000}
BOOT_KERNEL_OFFSET=${BOOT_KERNEL_OFFSET:-0x00008000}
BOOT_RAMDISK_OFFSET=${BOOT_RAMDISK_OFFSET:-0x02000000}
BOOT_TAGS_OFFSET=${BOOT_TAGS_OFFSET:-0x00000100}
BOOT_PAGESIZE=${BOOT_PAGESIZE:-4096}
BOOT_CMDLINE=${BOOT_CMDLINE:-}
TRAMPOLINE_SRC=${TRAMPOLINE_SRC:-"$ROOT_DIR/tools/lk-trampoline/trampoline.S"}
TRAMPOLINE_BUILD_DIR=${TRAMPOLINE_BUILD_DIR:-"$OUT_DIR/lk-trampoline-build"}
TRAMPOLINE_META_OFFSET=${TRAMPOLINE_META_OFFSET:-0x00000ff0}
TRAMPOLINE_PAYLOAD_OFFSET=${TRAMPOLINE_PAYLOAD_OFFSET:-0x00001000}
TRAMPOLINE_STACK=${TRAMPOLINE_STACK:-0x82000000}
MBN_PAYLOAD_ALIGN=${MBN_PAYLOAD_ALIGN:-8}
UEFI_PARTITION_SIZE=${UEFI_PARTITION_SIZE:-2560000}
APPSBL_ARTIFACT_NAME=${APPSBL_ARTIFACT_NAME:-u-boot-fame-appsbl-fastboot}
UEFI_IMAGE_NAME=${UEFI_IMAGE_NAME:-UEFI-u-boot-fame-appsbl-fastboot.bin}
LK_TEST_IMAGE_NAME=${LK_TEST_IMAGE_NAME:-u-boot-fame-appsbl-fastboot-lk-trampoline.img}
SKIP_LINUX=${SKIP_LINUX:-0}
SKIP_UBOOT=${SKIP_UBOOT:-0}

TRAMPOLINE_LOAD_ADDR=$(printf '0x%08x' $((BOOT_BASE + BOOT_KERNEL_OFFSET)))
U_BOOT_BIN="$U_BOOT_BUILD_DIR/u-boot-dtb.bin"
LK_TEST_IMAGE="$OUT_DIR/$LK_TEST_IMAGE_NAME"
TRAMPOLINE_ELF="$TRAMPOLINE_BUILD_DIR/lk-trampoline.elf"
TRAMPOLINE_BIN="$TRAMPOLINE_BUILD_DIR/lk-trampoline.bin"
TRAMPOLINE_KERNEL="$TRAMPOLINE_BUILD_DIR/u-boot-fame-appsbl-fastboot-lk-trampoline-kernel.bin"

[[ -f "$TRAMPOLINE_SRC" ]] || die "trampoline source not found: $TRAMPOLINE_SRC"
[[ $((TRAMPOLINE_META_OFFSET)) -gt 0 ]] || die "TRAMPOLINE_META_OFFSET must be greater than zero"
[[ $((TRAMPOLINE_PAYLOAD_OFFSET)) -gt $((TRAMPOLINE_META_OFFSET + 12)) ]] || \
	die "TRAMPOLINE_PAYLOAD_OFFSET must leave room for metadata"

common_args=(
	LINUX_DIR="$LINUX_DIR"
	U_BOOT_DIR="$U_BOOT_DIR"
	OUT_DIR="$OUT_DIR"
	LINUX_BUILD_DIR="$LINUX_BUILD_DIR"
	U_BOOT_BUILD_DIR="$U_BOOT_BUILD_DIR"
	DEFCONFIG="$DEFCONFIG"
	DTB="$DTB"
	LINUX_DT_TARGET="$LINUX_DT_TARGET"
	JOBS="$JOBS"
)

if [[ -n "${CROSS_COMPILE:-}" ]]; then
	need "${CROSS_COMPILE}gcc"
	need "${CROSS_COMPILE}objcopy"
	common_args+=(CROSS_COMPILE="$CROSS_COMPILE")
else
	for prefix in arm-none-eabi- arm-linux-gnueabi- arm-linux-gnueabihf- arm-linux-gnu-; do
		if have "${prefix}gcc" && have "${prefix}objcopy"; then
			CROSS_COMPILE=$prefix
			break
		fi
	done
fi

[[ -n "${CROSS_COMPILE:-}" ]] || die 'no ARM GCC cross compiler found; set CROSS_COMPILE='
need mkbootimg
need perl
need sha256sum
need stat

printf '==> Building APPSBL fastboot image\n'
"$ROOT_DIR/build-u-boot-uefi-smoke.sh" \
	"${common_args[@]}" \
	TEXT_BASE="$TEXT_BASE" \
	MBN_PAYLOAD_ALIGN="$MBN_PAYLOAD_ALIGN" \
	UEFI_PARTITION_SIZE="$UEFI_PARTITION_SIZE" \
	ARTIFACT_NAME="$APPSBL_ARTIFACT_NAME" \
	UEFI_IMAGE_NAME="$UEFI_IMAGE_NAME" \
	SKIP_LINUX="$SKIP_LINUX" \
	SKIP_UBOOT="$SKIP_UBOOT"

[[ -f "$U_BOOT_BIN" ]] || die "missing U-Boot payload: $U_BOOT_BIN"

mkdir -p "$TRAMPOLINE_BUILD_DIR"

printf '\n==> Building LK-safe trampoline\n'
"${CROSS_COMPILE}gcc" \
	-nostdlib \
	-ffreestanding \
	-Wl,-Ttext,"$TRAMPOLINE_LOAD_ADDR" \
	-Wl,--build-id=none \
	-DTRAMPOLINE_LOAD_ADDR="$TRAMPOLINE_LOAD_ADDR" \
	-DTRAMPOLINE_META_OFFSET="$TRAMPOLINE_META_OFFSET" \
	-DTRAMPOLINE_PAYLOAD_OFFSET="$TRAMPOLINE_PAYLOAD_OFFSET" \
	-DTRAMPOLINE_STACK="$TRAMPOLINE_STACK" \
	-o "$TRAMPOLINE_ELF" \
	"$TRAMPOLINE_SRC"
"${CROSS_COMPILE}objcopy" -O binary "$TRAMPOLINE_ELF" "$TRAMPOLINE_BIN"

printf '==> Packaging LK-chain trampoline image\n'
perl -e '
use strict;
use warnings;

my ($stub, $payload, $out, $dst_arg, $entry_arg, $meta_arg, $payload_arg) = @ARGV;
my $dst = $dst_arg =~ /^0x/i ? hex($dst_arg) : int($dst_arg);
my $entry = $entry_arg =~ /^0x/i ? hex($entry_arg) : int($entry_arg);
my $meta_offset = $meta_arg =~ /^0x/i ? hex($meta_arg) : int($meta_arg);
my $payload_offset = $payload_arg =~ /^0x/i ? hex($payload_arg) : int($payload_arg);
my $stub_size = -s $stub;
my $payload_size = -s $payload;
die "missing stub\n" unless defined $stub_size;
die "missing payload\n" unless defined $payload_size;
die "stub size $stub_size exceeds metadata offset $meta_offset\n" if $stub_size > $meta_offset;
die "metadata overlaps payload offset\n" if $meta_offset + 12 > $payload_offset;

open my $stub_fh, "<:raw", $stub or die "open $stub: $!\n";
open my $payload_fh, "<:raw", $payload or die "open $payload: $!\n";
open my $out_fh, ">:raw", $out or die "open $out: $!\n";

while (1) {
	my $buf;
	my $n = read($stub_fh, $buf, 1024 * 1024);
	die "read $stub: $!\n" unless defined $n;
	last if $n == 0;
	print {$out_fh} $buf or die "write $out: $!\n";
}

print {$out_fh} "\0" x ($meta_offset - $stub_size) or die "pad metadata: $!\n";
print {$out_fh} pack("V3", $dst, $entry, $payload_size) or die "write metadata: $!\n";
print {$out_fh} "\0" x ($payload_offset - $meta_offset - 12) or die "pad payload: $!\n";

while (1) {
	my $buf;
	my $n = read($payload_fh, $buf, 1024 * 1024);
	die "read $payload: $!\n" unless defined $n;
	last if $n == 0;
	print {$out_fh} $buf or die "write $out: $!\n";
}

close $out_fh or die "close $out: $!\n";
close $payload_fh or die "close $payload: $!\n";
close $stub_fh or die "close $stub: $!\n";
' "$TRAMPOLINE_BIN" "$U_BOOT_BIN" "$TRAMPOLINE_KERNEL" "$TEXT_BASE" "$TEXT_BASE" \
	"$TRAMPOLINE_META_OFFSET" "$TRAMPOLINE_PAYLOAD_OFFSET"

mkbootimg_args=(
	--header_version 0
	--kernel "$TRAMPOLINE_KERNEL"
	--base "$BOOT_BASE"
	--kernel_offset "$BOOT_KERNEL_OFFSET"
	--ramdisk_offset "$BOOT_RAMDISK_OFFSET"
	--tags_offset "$BOOT_TAGS_OFFSET"
	--pagesize "$BOOT_PAGESIZE"
	--board nokia-fame
	-o "$LK_TEST_IMAGE"
)

if [[ -n "$BOOT_CMDLINE" ]]; then
	mkbootimg_args+=(--cmdline "$BOOT_CMDLINE")
fi

mkbootimg "${mkbootimg_args[@]}"

trampoline_size=$(stat -c%s "$TRAMPOLINE_BIN")
payload_size=$(stat -c%s "$U_BOOT_BIN")
kernel_size=$(stat -c%s "$TRAMPOLINE_KERNEL")
image_size=$(stat -c%s "$LK_TEST_IMAGE")
kernel_sha256=$(sha256sum "$TRAMPOLINE_KERNEL" | cut -d' ' -f1)
image_sha256=$(sha256sum "$LK_TEST_IMAGE" | cut -d' ' -f1)

printf '\n==> Wrote LK trampoline artifact\n'
printf '    trampoline: %s (%s bytes)\n' "$TRAMPOLINE_BIN" "$trampoline_size"
printf '    payload:    %s (%s bytes)\n' "$U_BOOT_BIN" "$payload_size"
printf '    kernel:     %s (%s bytes, sha256 %s)\n' "$TRAMPOLINE_KERNEL" "$kernel_size" "$kernel_sha256"
printf '    boot img:   %s (%s bytes, sha256 %s)\n' "$LK_TEST_IMAGE" "$image_size" "$image_sha256"
printf '    lk kernel:  %s\n' "$TRAMPOLINE_LOAD_ADDR"
printf '    payload:    %s -> %s\n' "$(printf '0x%08x' $((BOOT_BASE + BOOT_KERNEL_OFFSET + TRAMPOLINE_PAYLOAD_OFFSET)))" "$TEXT_BASE"

printf '\nRun from the working LK fastboot prompt:\n'
printf '  fastboot boot %q\n' "$LK_TEST_IMAGE"
