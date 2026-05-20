# Nokia Lumia 520 Mainlining

Mainline bring-up workspace for Nokia Lumia 520, codename `fame`, on Qualcomm MSM8227. The current hardware target is an unlocked RM-914 unit with `TYPE=RM-914` and `CTR=059S083`.

The active kernel source is `linux/`, pinned for this first pass to `msm8227-mainline/msm8227-6.19` because it already contains `arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dts`. The active U-Boot source is `u-boot/`, currently upstream-based with raw APPSBL UART and LK-chain fastboot candidates.

This repository is the workspace and research ledger. Keep source facts, provenance, and test outcomes here; keep FFUs, extracted partitions, and firmware blobs local under `extracted/`.

## Current Test Bias

UART output is now available after hardware rework. Treat host-to-device UART input as unreliable until proven; RX-only logs are enough for the first raw U-Boot smoke tests.

Safe read-only BootMgr/Lumia inventory commands live in `~/src/lp-externals`:

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
| Missing | Not implemented or not yet inventoried. |

## Bring-Up Matrix

| Area | Current State | Notes |
| --- | --- | --- |
| BootMgr inventory | Candidate | `lp-externals` has read-only `NOKV` and `NOKT` support. |
| FFU inventory | Missing | No local FFU artifacts found during bootstrap. |
| Kernel DTS | Candidate | `linux/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dts` exists and its DTB builds with `qcom_defconfig`. |
| U-Boot | Working | Raw APPSBL UART reaches a prompt; LK-chain Android boot image enumerates U-Boot USB fastboot and can chain U-Boot-to-U-Boot. |
| UART | Candidate | Device-to-host UART output is available; host-to-device RX is suspected damaged. |
| Display | Hypothesis | Android4Lumia says Orise-based 800x480; ACPI/PCFG extraction is the next high-trust path. |
| Touch | Hypothesis | Android4Lumia says Synaptics; Fame DTS has disabled RMI4 sketch. |
| USB gadget/UDC | Working | U-Boot ChipIdea/ULPI fastboot responds to `fastboot getvar all`; current rebuild enables `bootm`/`abootimg`, `oem run`, console capture, nested `fastboot boot`, and block-backed `fastboot flash`. |
| eMMC | Working | LK-chain U-Boot initializes SDCC1/eMMC, reports the 8-bit MMC 4.5 device, reads blocks, and lists GPT partitions. |

## Useful Files

| File | Purpose |
| --- | --- |
| `AGENTS.md` | Workspace rules, safety constraints, source trust, and active paths. |
| `RESEARCH.md` | Small index for detailed notes. |
| `STATUS.md` | Current implementation state and next work. |
| `build-u-boot-uefi-smoke.sh` | Builds the Linux DTB, raw U-Boot, and padded `UEFI` UART smoke image. |
| `build-u-boot-lk-fastboot.sh` | Builds the Linux DTB, U-Boot fastboot gadget config, and Android boot image for `fastboot boot` from LK. |
| `notes/source-trust.md` | Trust model for FFU/live/community/adjacent facts. |
| `notes/prior-art-index.md` | Submodule inventory and key source paths. |
| `notes/bootmgr-protocol.md` | Read-only BootMgr/Lumia USB protocol notes. |
| `notes/ffu-inventory.md` | Local FFU extraction plan and inventory placeholder. |
| `notes/hardware-inventory.md` | Hardware facts with provenance. |
