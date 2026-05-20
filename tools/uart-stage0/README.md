# UART Stage0 Recovery Loader

This directory contains a tiny ARM32 UART loader for escaping from a U-Boot APPSBL image that has UART but no working USB, storage, reset, or serial-load commands.

The loader is pasted into U-Boot with `mw.l`, started with `go`, receives a raw payload over UART, copies it to RAM, and jumps to it. The default payload is the proven Android4Lumia LK raw binary.

## Build

```sh
tools/uart-stage0/build.sh
```

Expected output is `tools/uart-stage0/build/stage0.bin` plus a manual paste script at `tools/uart-stage0/build/stage0-mw.txt`.

## Boot LK Through U-Boot UART

Run this on the machine connected to the phone UART while the phone is sitting at the U-Boot `=>` prompt:

```sh
tools/uart-stage0/send-payload.py --port /dev/ttyUSB0
```

If the first run successfully printed `FAMESTG0 READY` but the host script timed out before sending the payload, do not reset or re-paste stage0. Resume the transfer with:

```sh
tools/uart-stage0/send-payload.py --port /dev/ttyUSB0 --resume-stage0
```

Defaults:

| Item | Value |
| --- | --- |
| Stage0 load/entry | `0x82000000` |
| Payload | `out/fame/android4lumia-lk-build/build-msm8960/lk.bin` |
| Payload load/entry | `0x88f00000` |
| UART | `115200 8n1` |

Once LK starts, use fastboot to flash a persistent rescue image before rebooting.

## Persistent Rescue Candidate

Known-good LK APPSBL partition image:

```text
out/fame/android4lumia-lk-build/UEFI-android4lumia-lk-msm8960.bin
```

Stock UEFI image, if available on the same machine:

```text
extracted/partitions/RM-914-059S083/UEFI.bin
```

Prefer restoring stock UEFI if the goal is to get back to BootMgr/FlashApp. Prefer LK only if the goal is to keep a fastboot recovery APPSBL while continuing U-Boot bring-up.
