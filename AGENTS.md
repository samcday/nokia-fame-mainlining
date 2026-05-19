# Nokia Lumia 520 / fame Bring-Up Notes

Device: Nokia Lumia 520, codename `fame`, current unit `RM-914` / `059S083`, Qualcomm MSM8227 / Lumia platform `Nokia.MSM8227.P6036.1.2`.

## Workspace

`linux/` and `u-boot/` are checked in as submodules, but in day-to-day work they may be worktrees from the canonical `~/src/linux` and `~/src/u-boot` repositories. Do not assume their `origin` remote is the same as `.gitmodules`.

Current top-level submodule baseline:

| Path | Role |
| --- | --- |
| `linux/` | Kernel tree, initially pinned to `msm8227-mainline/msm8227-6.19`. |
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

## Kernel Notes

Initial kernel baseline is `linux/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dts` from `msm8227-mainline/msm8227-6.19`.

Before changing a GPIO, regulator, memory range, partition offset, boot image layout value, panel command, or other non-obvious hardware fact, add or update a breadcrumb in `notes/*.md` with exact source paths and line ranges.

Known DTS cleanup candidates from the bootstrap pass:

| Issue | Path |
| --- | --- |
| `drive-strengh` typo in SDCC pinctrl properties | `linux/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dts` |
| SD card marked `non-removable` despite pmaports external storage clue | same |
| Touchscreen node is commented out and unvalidated | same |
| WCNSS local MAC is fake in common DTSI | `linux/arch/arm/boot/dts/qcom/qcom-msm8227-common.dtsi` |

## U-Boot Notes

Do not assume U-Boot can simply be dropped into the ESP as an ARM UEFI application. In current U-Boot, `CONFIG_EFI_APP` is gated to x86 even though some ARM EFI object files exist.

The Samsung Express workspace has reusable ARM32 Snapdragon experiments: `ARCH_SNAPDRAGON_ARM32`, MSM8960-style timer setup, UARTDM v1.3/GSBI serial support, and a minimal ARM32 defconfig pattern. These are not yet integrated here.

Because there is no UART path, a fastboot-only U-Boot chainloader is risky until USB gadget/PHY clocks are proven. Prefer visible/observable payload experiments and kernel UDC bring-up before relying on U-Boot fastboot.
