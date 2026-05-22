# Nokia Lumia 520 Mainlining

Mainline bring-up workspace for Nokia Lumia 520, codename `fame`, on Qualcomm MSM8227. The current hardware target is an unlocked RM-914 unit with `TYPE=RM-914` and `CTR=059S083`.

The active kernel source is `linux/` on the local `nokia-fame` branch, targeting upstreamable mainline changes. The active U-Boot source is `u-boot/`; the current device has persistent raw APPSBL U-Boot in the `UEFI` partition, with working USB fastboot and `oem run`/`oem console` command access.

This repository is the workspace and research ledger. Keep source facts, provenance, and test outcomes here; keep FFUs, extracted partitions, and firmware blobs local under `extracted/`.

## Current Test Bias

UART output is available after hardware rework. Treat host-to-device UART input as unreliable until proven; persistent U-Boot fastboot is the primary non-flashing kernel test path.

Build a first Linux boot image with:

```sh
./build-linux-fastboot.sh
```

Boot it from persistent U-Boot without writing flash:

```sh
fastboot boot out/fame/fame-linux-fastboot.img
```

Safe read-only BootMgr/Lumia inventory commands live in `~/src/lp-externals` if stock BootMgr/FlashApp is restored:

```sh
cargo run --manifest-path ~/src/lp-externals/Cargo.toml -- stay-awake
cargo run --manifest-path ~/src/lp-externals/Cargo.toml -- identify
cargo run --manifest-path ~/src/lp-externals/Cargo.toml -- gpt dump
cargo run --manifest-path ~/src/lp-externals/Cargo.toml -- switch phone-info
cargo run --manifest-path ~/src/lp-externals/Cargo.toml -- phone-info read TYPE
cargo run --manifest-path ~/src/lp-externals/Cargo.toml -- phone-info read CTR
```

Known LumiaDB plan from `~/src/lp-externals/UNLOCKING.md`:

```text
TYPE = RM-914
CTR  = 059S083
FFU  = RM914_3058.50000.1425.0001_RETAIL_eu_euro2_218_01_452872_prd_signed.ffu
```

## Status Legend

| Status | Meaning |
| --- | --- |
| Working | Tested on hardware in this workspace. |
| Candidate | Present in a source tree, but not yet validated on this unit. |
| Hypothesis | Community/adjacent clue only. |
| Historical | Previously useful path, but not the current live boot state. |
| Missing | Not implemented or not yet inventoried. |

## Bring-Up Matrix

| Area | Current State | Notes |
| --- | --- | --- |
| BootMgr inventory | Historical | `lp-externals` has read-only `NOKV` and `NOKT` support; the live device currently boots U-Boot instead of Nokia BootMgr. |
| FFU inventory | Working | Stock RM-914 / `059S083` FFU and PLAT/ACPI artifacts are inventoried under `notes/`. |
| Kernel DTS | Candidate | `linux/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dts` has minimal UART, USB1/ULPI, SDCC1/eMMC, and PSHOLD support and builds with `qcom_defconfig`. |
| Kernel boot harness | Candidate | `./build-linux-fastboot.sh` packages `Image.gz`, Android boot-image v2 DTB payload, and the local mini-initrd for non-flashing `fastboot boot` from persistent U-Boot. |
| U-Boot | Working | Persistent raw APPSBL U-Boot in `UEFI` enumerates USB fastboot and supports `reboot`, `flash`, `fetch`, `oem run`, and `oem console`. |
| UART | Candidate | Device-to-host UART output is available; host-to-device RX is suspected damaged. |
| Display | Hypothesis | FFU PCFG says Teisko 480x800 24bpp DSI; simple framebuffer handoff still needs hardware testing. |
| Touch | Hypothesis | FFU ACPI corroborates I2C address `0x4b`, IRQ GPIO11, and reset GPIO52; controller identity and supplies remain unvalidated. |
| USB gadget/UDC | Working / Candidate | U-Boot ChipIdea/ULPI fastboot works; Linux UDC is the next hardware test via the mini-initrd CDC-ACM gadget. |
| eMMC | Working | U-Boot initializes SDCC1/eMMC, reports the 8-bit MMC 4.5 device, reads blocks, and lists GPT partitions. |

## Useful Files

| File | Purpose |
| --- | --- |
| `AGENTS.md` | Workspace rules, safety constraints, source trust, and active paths. |
| `RESEARCH.md` | Small index for detailed notes. |
| `STATUS.md` | Current implementation state and next work. |
| `build-linux-fastboot.sh` | Builds Linux, mini-initrd, and a non-flashing Android boot image for persistent U-Boot `fastboot boot`. |
| `build-minitrd.sh` | Builds the mkosi/APK BusyBox mini-initrd used for UART and CDC-ACM gadget shell tests. |
| `build-u-boot.sh` | Builds the Linux DTB, PIE APPSBL U-Boot, a non-flashing legacy standalone `fastboot boot` image, and a `fastboot flash UEFI` MBN. |
| `notes/source-trust.md` | Trust model for FFU/live/community/adjacent facts. |
| `notes/prior-art-index.md` | Submodule inventory and key source paths. |
| `notes/bootmgr-protocol.md` | Read-only BootMgr/Lumia USB protocol notes. |
| `notes/ffu-inventory.md` | Local FFU extraction plan and inventory placeholder. |
| `notes/hardware-inventory.md` | Hardware facts with provenance. |
| `notes/usb-and-initramfs.md` | Linux USB gadget, mini-initrd, and boot-image layout notes. |
