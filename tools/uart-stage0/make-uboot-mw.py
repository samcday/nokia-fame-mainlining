#!/usr/bin/env python3
# SPDX-License-Identifier: MIT

import argparse
import struct
from pathlib import Path


def parse_u32(value: str) -> int:
    return int(value, 0) & 0xFFFFFFFF


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate U-Boot mw.l commands for a binary")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--address", required=True, type=parse_u32)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    data = args.input.read_bytes()
    if len(data) % 4:
        data += b"\0" * (4 - len(data) % 4)

    lines = []
    for offset in range(0, len(data), 4):
        (word,) = struct.unpack_from("<I", data, offset)
        lines.append(f"mw.l 0x{args.address + offset:08x} 0x{word:08x} 1")

    lines.append(f"go 0x{args.address:08x}")
    args.output.write_text("\n".join(lines) + "\n", encoding="ascii")


if __name__ == "__main__":
    main()
