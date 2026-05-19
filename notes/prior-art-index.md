# Prior-Art Index

## Submodules

| Path | Source | Trust | Notes |
| --- | --- | --- | --- |
| `linux/` | `msm8227-mainline/linux`, branch `msm8227-6.19` | C/E | Existing MSM8227 near-mainline tree with Fame DTS. |
| `u-boot/` | upstream U-Boot | E | No Fame support yet. |
| `community/android4lumia-device-fame/` | Android4Lumia device tree | C | Hardware sketch and blob inventory. |
| `community/android4lumia-kernel-msm8x27/` | Android4Lumia kernel | C | Linux 3.4 community kernel; config includes panel/touch/USB clues. |
| `community/android4lumia-lk-msm8227/` | Android4Lumia bootloader/LK | C | Community LK and possible display/UEFI handoff hints. |
| `community/android4lumia-notes/` | Android4Lumia notes/manifests | C | Project metadata. |
| `prior-art/mainline4lumia-linux/` | Mainline4Lumia kernel | D | Adjacent Lumia mainlining. |
| `prior-art/mainline4lumia-lk2nd/` | Mainline4Lumia lk2nd | D | Lumia bootloader methodology. |
| `prior-art/mainline4lumia-scripts/` | Mainline4Lumia scripts | D | Contains ACPI panel PCFG extractor. |
| `prior-art/WPinternals/` | WPinternals | D | BootMgr/FlashApp/PhoneInfo protocol source. |
| `prior-art/woa-lumia950xl-pkg/` | WOA Lumia950XLPkg | D | Later Lumia ACPI/UEFI reference. |
| `tools/img2ffu/` | MobileTooling img2ffu | D | FFU format/layout reference. |

## High-Value Paths

| Path | Why It Matters |
| --- | --- |
| `linux/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dts` | Existing Fame DTS skeleton. |
| `linux/arch/arm/boot/dts/qcom/qcom-msm8227-common.dtsi` | Current SoC common description used by Fame. |
| `linux/arch/arm/boot/dts/qcom/qcom-msm8227-sony-nicki.dts` | Closest sibling MSM8227 reference. |
| `community/android4lumia-device-fame/README.md` | Device spec and variant summary. |
| `community/android4lumia-device-fame/BoardConfig.mk` | Android boot/image and subsystem clues. |
| `community/android4lumia-kernel-msm8x27/arch/arm/configs/lineage_fame_defconfig` | Panel/touch/USB/storage config clues. |
| `prior-art/mainline4lumia-scripts/scripts/acpi_panel_extractor.py` | Extracts Lumia panel PCFG XML from decompiled DSDT. |
| `~/src/lp-externals/PROTOCOL.md` | Local Rust BootMgr/FlashApp protocol notes. |
| `~/src/lp-externals/UNLOCKING.md` | Known RM-914/CTR/LumiaDB facts for this unit. |
