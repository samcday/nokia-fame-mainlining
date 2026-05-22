#!/usr/bin/env bash
# Build the local mkosi/APK mini initrd for Fame kernel bring-up.

set -euo pipefail

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

have() {
	command -v "$1" >/dev/null 2>&1
}

usage() {
	cat <<'EOF'
Usage: ./build-minitrd.sh [KEY=value ...]

Builds ./minitrd with mkosi as an Alpine/postmarketOS-derived ARMv7 cpio.gz initramfs.

Environment overrides:

  MKOSI       mkosi executable (default: $HOME/src/mkosi/bin/mkosi)
  OUT_DIR     Output directory (default: ./out/fame)
  OUTPUT      Output cpio.gz (default: $OUT_DIR/minitrd.cpio.gz)
  KEEP_WORK=1 Keep mkosi workspace artifacts for inspection (default: 0)
  CLEAN_CACHE=1 Remove mkosi tree/build/package caches before building (default: 0)
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
MKOSI=${MKOSI:-"$HOME/src/mkosi/bin/mkosi"}
OUT_DIR=${OUT_DIR:-"$ROOT_DIR/out/fame"}
OUTPUT=${OUTPUT:-"$OUT_DIR/minitrd.cpio.gz"}
KEEP_WORK=${KEEP_WORK:-0}
CLEAN_CACHE=${CLEAN_CACHE:-0}

[[ -x "$MKOSI" ]] || die "mkosi not executable: $MKOSI"
have stat || die 'missing required tool: stat'

MINITRD_DIR="$ROOT_DIR/minitrd"
MKOSI_OUTPUT="$MINITRD_DIR/mkosi.output/minitrd.cpio.gz"
WORKSPACE_DIR="$OUT_DIR/minitrd-mkosi-workspace"

[[ -f "$MINITRD_DIR/mkosi.conf" ]] || die "missing mkosi config: $MINITRD_DIR/mkosi.conf"
mkdir -p "$OUT_DIR" \
	"$MINITRD_DIR/mkosi.output" \
	"$MINITRD_DIR/mkosi.cache" \
	"$MINITRD_DIR/mkosi.pkgcache" \
	"$MINITRD_DIR/mkosi.builddir"

if [[ "$CLEAN_CACHE" == 1 ]]; then
	rm -rf "$MINITRD_DIR/mkosi.cache" "$MINITRD_DIR/mkosi.pkgcache" "$MINITRD_DIR/mkosi.builddir"
	mkdir -p "$MINITRD_DIR/mkosi.cache" "$MINITRD_DIR/mkosi.pkgcache" "$MINITRD_DIR/mkosi.builddir"
fi

if [[ "$KEEP_WORK" != 1 ]]; then
	rm -rf "$WORKSPACE_DIR"
fi

printf '==> Building minitrd with %s\n' "$MKOSI"
"$MKOSI" \
	-C "$MINITRD_DIR" \
	--force \
	--workspace-directory "$WORKSPACE_DIR" \
	build

[[ -f "$MKOSI_OUTPUT" ]] || die "mkosi output not found: $MKOSI_OUTPUT"
install -m 0644 "$MKOSI_OUTPUT" "$OUTPUT"

size=$(stat -c%s "$OUTPUT")
printf '==> Wrote minitrd %s (%s bytes)\n' "$OUTPUT" "$size"
