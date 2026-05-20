#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Paste stage0 through U-Boot and stream a raw payload over UART.

This intentionally uses only Python's standard library so it can run on a
minimal recovery laptop without pyserial installed.
"""

from __future__ import annotations

import argparse
import os
import select
import struct
import sys
import termios
import time
from pathlib import Path


MAGIC = b"FAMESTG0"
DEFAULT_STAGE0 = Path(__file__).resolve().parent / "build" / "stage0.bin"
DEFAULT_PAYLOAD = (
    Path(__file__).resolve().parents[2]
    / "out"
    / "fame"
    / "android4lumia-lk-build"
    / "build-msm8960"
    / "lk.bin"
)


def parse_u32(value: str) -> int:
    return int(value, 0) & 0xFFFFFFFF


def baud_constant(baud: int) -> int:
    name = f"B{baud}"
    try:
        return getattr(termios, name)
    except AttributeError as exc:
        raise SystemExit(f"unsupported baud rate: {baud}") from exc


def configure_serial(fd: int, baud: int, flush: bool = True):
    old = termios.tcgetattr(fd)
    attrs = termios.tcgetattr(fd)
    speed = baud_constant(baud)

    attrs[0] &= ~(termios.IGNBRK | termios.BRKINT | termios.PARMRK | termios.ISTRIP |
                  termios.INLCR | termios.IGNCR | termios.ICRNL | termios.IXON |
                  termios.IXOFF | termios.IXANY)
    attrs[1] &= ~termios.OPOST
    attrs[2] &= ~(termios.CSIZE | termios.PARENB | termios.CSTOPB | termios.CRTSCTS)
    attrs[2] |= termios.CS8 | termios.CREAD | termios.CLOCAL
    attrs[3] &= ~(termios.ECHO | termios.ECHONL | termios.ICANON | termios.ISIG | termios.IEXTEN)
    attrs[4] = speed
    attrs[5] = speed
    attrs[6][termios.VMIN] = 0
    attrs[6][termios.VTIME] = 1

    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    if flush:
        termios.tcflush(fd, termios.TCIOFLUSH)
    return old


def read_available(fd: int, timeout: float) -> bytes:
    ready, _, _ = select.select([fd], [], [], timeout)
    if not ready:
        return b""
    try:
        return os.read(fd, 4096)
    except BlockingIOError:
        return b""


def tee(data: bytes) -> None:
    if data:
        sys.stdout.buffer.write(data)
        sys.stdout.buffer.flush()


def wait_for(fd: int, needle: bytes, timeout: float, label: str) -> bytes:
    end = time.monotonic() + timeout
    buf = b""
    while time.monotonic() < end:
        chunk = read_available(fd, 0.1)
        tee(chunk)
        if chunk:
            buf += chunk
            if needle in buf:
                return buf
            if len(buf) > 8192:
                buf = buf[-4096:]
    raise TimeoutError(f"timed out waiting for {label}")


def write_line(fd: int, line: str) -> None:
    write_all(fd, line.encode("ascii") + b"\r")


def write_all(fd: int, data: bytes) -> None:
    view = memoryview(data)
    offset = 0
    while offset < len(view):
        try:
            written = os.write(fd, view[offset:])
        except BlockingIOError:
            select.select([], [fd], [], 1.0)
            continue
        if written == 0:
            select.select([], [fd], [], 1.0)
            continue
        offset += written


def paste_stage0(fd: int, stage0: bytes, address: int, prompt: bytes, timeout: float) -> None:
    padded = stage0 + b"\0" * ((4 - len(stage0) % 4) % 4)
    words = len(padded) // 4

    write_line(fd, "")
    wait_for(fd, prompt, timeout, "U-Boot prompt")

    for index, offset in enumerate(range(0, len(padded), 4), start=1):
        (word,) = struct.unpack_from("<I", padded, offset)
        write_line(fd, f"mw.l 0x{address + offset:08x} 0x{word:08x} 1")
        wait_for(fd, prompt, timeout, "U-Boot prompt after mw.l")
        if index == 1 or index == words or index % 32 == 0:
            print(f"\rloaded stage0 word {index}/{words}", end="", flush=True)
    print()

    write_line(fd, f"go 0x{address:08x}")


def stream_payload(fd: int, payload: bytes, load: int, entry: int, chunk_size: int, delay: float,
                   payload_offset: int) -> None:
    checksum = sum(payload) & 0xFFFFFFFF
    if payload_offset == 0:
        header = MAGIC + struct.pack("<IIII", load, entry, len(payload), checksum)
        write_all(fd, header)
        if delay:
            time.sleep(delay)
    else:
        print(f"continuing already-started transfer at payload offset {payload_offset}")

    sent = payload_offset
    started = time.monotonic()
    while sent < len(payload):
        chunk = payload[sent:sent + chunk_size]
        write_all(fd, chunk)
        sent += len(chunk)
        if sent == len(payload) or sent == len(chunk) or sent % (16 * 1024) < len(chunk):
            elapsed = max(time.monotonic() - started, 0.001)
            rate = (sent - payload_offset) / elapsed
            print(f"\rsent {sent}/{len(payload)} bytes ({rate:.0f} B/s)", end="", flush=True)
    print()


def main() -> int:
    parser = argparse.ArgumentParser(description="Recover by booting a payload through U-Boot UART")
    parser.add_argument("--port", required=True, help="UART device, e.g. /dev/ttyUSB0")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--stage0", type=Path, default=DEFAULT_STAGE0)
    parser.add_argument("--stage0-address", type=parse_u32, default=0x82000000)
    parser.add_argument("--payload", type=Path, default=DEFAULT_PAYLOAD)
    parser.add_argument("--load", type=parse_u32, default=0x88F00000)
    parser.add_argument("--entry", type=parse_u32, default=0x88F00000)
    parser.add_argument("--prompt", default="=> ")
    parser.add_argument("--prompt-timeout", type=float, default=5.0)
    parser.add_argument("--ready-timeout", type=float, default=10.0)
    parser.add_argument("--chunk-size", type=int, default=1024)
    parser.add_argument("--payload-offset", type=int, default=0,
                        help="continue a stage0 transfer from this payload byte offset; does not resend header")
    parser.add_argument("--header-delay", type=float, default=0.05,
                        help="delay after stage0 header before payload bytes")
    parser.add_argument("--resume-stage0", action="store_true",
                        help="stage0 is already running and waiting for the payload header")
    parser.add_argument("--skip-ready-wait", action="store_true",
                        help="send the payload after go without waiting for the READY banner")
    parser.add_argument("--tail-seconds", type=float, default=20.0,
                        help="print serial output for this long after payload transfer; 0 means forever")
    args = parser.parse_args()

    stage0 = args.stage0.read_bytes()
    payload = args.payload.read_bytes()

    print(f"stage0: {args.stage0} ({len(stage0)} bytes)")
    print(f"payload: {args.payload} ({len(payload)} bytes)")
    print(f"payload load=0x{args.load:08x} entry=0x{args.entry:08x}")

    fd = os.open(args.port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    old_attrs = configure_serial(fd, args.baud, flush=not args.resume_stage0)
    try:
        if args.resume_stage0:
            print("resuming: assuming stage0 is already waiting for the payload header")
        else:
            paste_stage0(fd, stage0, args.stage0_address, args.prompt.encode("ascii"), args.prompt_timeout)
            if args.skip_ready_wait:
                time.sleep(0.5)
            else:
                try:
                    wait_for(fd, b"FAMESTG0 READY", args.ready_timeout, "stage0 ready banner")
                except TimeoutError:
                    print("warning: READY banner not detected; sending payload anyway", file=sys.stderr)
        stream_payload(fd, payload, args.load, args.entry, args.chunk_size, args.header_delay,
                       args.payload_offset)

        print("waiting for stage0/LK output")
        end = None if args.tail_seconds == 0 else time.monotonic() + args.tail_seconds
        while end is None or time.monotonic() < end:
            tee(read_available(fd, 0.1))
        return 0
    finally:
        termios.tcsetattr(fd, termios.TCSANOW, old_attrs)
        os.close(fd)


if __name__ == "__main__":
    raise SystemExit(main())
