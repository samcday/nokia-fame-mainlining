# Nokia Lumia 520 Mainlining

Mainline bring-up workspace for Nokia Lumia 520, codename `fame`, on Qualcomm MSM8227. The current hardware target is an unlocked RM-914 unit with `TYPE=RM-914` and `CTR=059S083`.

The active kernel source is `linux/`, pinned for this first pass to `msm8227-mainline/msm8227-6.19` because it already contains `arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dts`. The active U-Boot source is `u-boot/`, currently upstream-based with no working Fame payload yet.

This repository is the workspace and research ledger. Keep source facts, provenance, and test outcomes here; keep FFUs, extracted partitions, and firmware blobs local under `extracted/`.

## Current Test Bias

There is no confirmed UART path for this unit yet. Treat early bring-up as USB/display-only unless hardware access changes.

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
| U-Boot | Missing | ARM32 Snapdragon patches exist in the Samsung workspace, but no Fame U-Boot build exists here yet. |
| UART | Missing | Work as USB/display-only for now. |
| Display | Hypothesis | Android4Lumia says Orise-based 800x480; ACPI/PCFG extraction is the next high-trust path. |
| Touch | Hypothesis | Android4Lumia says Synaptics; Fame DTS has disabled RMI4 sketch. |
| USB gadget/UDC | Candidate | Linux DTS enables `usb1`; U-Boot fastboot is higher risk because MSM8227 uses old ChipIdea/ULPI-era USB. |

## Useful Files

| File | Purpose |
| --- | --- |
| `AGENTS.md` | Workspace rules, safety constraints, source trust, and active paths. |
| `RESEARCH.md` | Small index for detailed notes. |
| `STATUS.md` | Current implementation state and next work. |
| `notes/source-trust.md` | Trust model for FFU/live/community/adjacent facts. |
| `notes/prior-art-index.md` | Submodule inventory and key source paths. |
| `notes/bootmgr-protocol.md` | Read-only BootMgr/Lumia USB protocol notes. |
| `notes/ffu-inventory.md` | Local FFU extraction plan and inventory placeholder. |
| `notes/hardware-inventory.md` | Hardware facts with provenance. |
