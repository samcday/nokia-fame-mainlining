# Nokia Lumia 520 / fame Bring-Up Notes

Device: Nokia Lumia 520, codename `fame`, current unit `RM-914` / `059S083`, Qualcomm MSM8227 / Lumia platform `Nokia.MSM8227.P6036.1.2`.

## Workspace

`linux/` and `u-boot/` are checked in as submodules, but in day-to-day work they may be worktrees from the canonical `~/src/linux` and `~/src/u-boot` repositories. Do not assume their `origin` remote is the same as `.gitmodules`.

Current top-level submodule baseline:

| Path | Role |
| --- | --- |
| `linux/` | Kernel tree, upstream-first; use current mainline as the baseline. |
| `u-boot/` | U-Boot tree, initially upstream-based. |
| `community/android4lumia-*` | Community Android reconstruction; use as hypotheses only. |
| `prior-art/mainline4lumia-*` | Adjacent Lumia methods and scripts. |
| `prior-art/WPinternals` | Lumia BootMgr/FlashApp/PhoneInfo protocol reference. |
| `tools/img2ffu` | FFU structure and flashing-layout reference. |

## Safety

Assume USB/display-only debugging unless the user says UART is available.

Do not run destructive Lumia commands unless explicitly requested by the user in that turn. This includes FlashApp raw writes, FFU restore, factory reset, soft-brick, secure-boot state changes, GPT writes, ESP writes, and any manufacturing/SecureBoot commands.

Safe initial live-device commands are read-only BootMgr/PhoneInfo inventory commands from `~/src/lp-externals`: `stay-awake`, `identify`, `gpt dump`, `switch phone-info`, `phone-info read TYPE`, and `phone-info read CTR`. Mode switches are allowed only when they are explicitly part of inventory and not flashing.

Never commit IMEI or other personal identifiers. Product type, product code, public firmware URL, and platform ID may be recorded.

Do not commit FFUs, raw partition dumps, firmware blobs, or unpacked proprietary images. Put them under `extracted/`; keep only inventories and scripts in git.

## Source Trust

Use this order when facts conflict:

| Tier | Source | How to Use |
| --- | --- | --- |
| A | Stock FFU-derived data | Highest trust for GPT, ESP, firmware names, ACPI/AML, PCFG XML, and partition contents. |
| B | Live BootMgr/PhoneInfo/FlashApp read-only facts | High trust for the current unit's mode, GPT, platform, TYPE/CTR, and protocol versions. |
| C | Community Android4Lumia/postmarketOS | Hypothesis source, not OEM Linux downstream. |
| D | Mainline4Lumia/WOA adjacent Lumia work | Method/reference source. |
| E | MSM8227/MSM8930 sibling devices | Style and generic SoC reference only. |

The local `samsung-expressltexx` kernel branch is a high-value MSM8930 sibling reference for shared SoC DT infrastructure and related driver enablement. Treat it as more trustworthy than Android4Lumia/community guesses for common MSM8930/MSM8227 infrastructure, but still below stock FFU-derived facts and live read-only device observations. It is acceptable for Fame and Express to temporarily duplicate common MSM8930/MSM8227 DT infrastructure; defer deduplication until both devices have stable bring-up.

## Kernel Notes

`linux/` work must target upstreamable Linux kernel patches from current mainline. Use `msm8227-mainline` and community trees only as references, not as the source of truth or a base to polish.

The active `linux/` and `u-boot/` branches are bring-up integration branches, not submission branches. Keep them recoverable by committing early and regularly rather than accumulating large uncommitted experiments. Use kernel-style subjects and commit messages for changes that appear upstreamable. Prefix uncertain exploratory commits with `WIP:`. Prefix intentionally dirty instrumentation, debug hacks, or throwaway experiments with `HACK:`. Do not bury debug logging or speculative hardware guesses in clean-looking commits; either document the evidence in `notes/*.md` and make it a real patch, or mark the commit honestly as WIP/HACK.

Before any work inside `linux/`, AI coding assistants must read `linux/README` and follow the referenced `linux/Documentation/process/coding-assistants.rst`. In particular, do not add `Signed-off-by` tags to kernel commits or patches; only the human submitter may certify DCO signoff. Follow the normal kernel development process, coding style, submitting-patches guidance, and devicetree binding requirements.

Before changing a GPIO, regulator, memory range, partition offset, boot image layout value, panel command, or other non-obvious hardware fact, add or update a breadcrumb in `notes/*.md` with exact source paths and line ranges.

For normal kernel bring-up builds, prefer the local helpers instead of open-coding kernel `make` commands:

| Helper | Purpose |
| --- | --- |
| `./build-linux-fastboot.sh` | Builds `linux/`, builds the mini-initrd, packages `Image.gz` plus Android boot-image v2 DTB payload, and writes `out/fame/fame-linux-fastboot.img` for persistent U-Boot `fastboot boot`. |
| `./build-minitrd.sh` | Builds the mkosi/APK BusyBox mini-initrd with UART and CDC-ACM gadget shell setup. |

The persistent U-Boot fastboot path is the default non-flashing kernel test path. Safe U-Boot-side read/test commands include `fastboot getvar`, `fastboot boot`, `fastboot fetch`, and targeted `fastboot oem run` diagnostics. Treat `fastboot flash`, `fastboot erase`, GPT writes, ESP writes, and firmware partition writes as destructive unless the user explicitly requests that exact operation in the current turn.

Known DTS cleanup candidates from the bootstrap pass:

| Issue | Path |
| --- | --- |
| `drive-strengh` typo in SDCC pinctrl properties | `linux/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dts` |
| SD card marked `non-removable` despite pmaports external storage clue | same |
| Touchscreen node is commented out and unvalidated | same |
| WCNSS local MAC is fake in common DTSI | `linux/arch/arm/boot/dts/qcom/qcom-msm8227-common.dtsi` |

## U-Boot Notes

Do not assume U-Boot can simply be dropped into the ESP as an ARM UEFI application. In current U-Boot, `CONFIG_EFI_APP` is gated to x86 even though some ARM EFI object files exist.

Current live path: raw APPSBL U-Boot is flashed to `UEFI`, comes up over UART, and falls back to USB fastboot when autoboot fails. This is now good enough for kernel `fastboot boot` iterations, but keep a clear recovery path before any persistent bootloader or partition write.
