# ACPI And Platform Config

The stock FFU `PLAT` partition contains ACPI tables and platform config for Fame. Treat these as tier-A board facts, but decode raw ACPI resource buffers carefully before changing DTS GPIOs, regulators, clocks, or memory maps.

## Extracted Files

Local extraction root: `extracted/acpi-or-platform-config/RM-914-059S083/PLAT-files/`

| File | Size | Notes |
| --- | --- | --- |
| `ACPI/dsdt.aml` | `70813` | Main DSDT. |
| `ACPI/dsdt.dsl` | `781459` | Decompiled from `dsdt.aml`. |
| `ACPI/ssdt.aml` | `3364` | Nokia SSDT. |
| `ACPI/ssdt.dsl` | `29170` | Decompiled from `ssdt.aml`. |
| `panel-pcfg.xml` | `4916` | Extracted from DSDT `_ROM` `PCFG`. |

Other PLAT ACPI files present: `bgrt.acp`, `csrt.acp`, `dbg2.acp`, `facp.acp`, `facs.acp`, `fpdt.acp`, `madt.acp`, `tpm2.acp`, and `wdat.acp`.

## Decompile And Extract Commands

```sh
iasl -d \
  extracted/acpi-or-platform-config/RM-914-059S083/PLAT-files/ACPI/dsdt.aml \
  extracted/acpi-or-platform-config/RM-914-059S083/PLAT-files/ACPI/ssdt.aml
python3 prior-art/mainline4lumia-scripts/scripts/acpi_panel_extractor.py \
  extracted/acpi-or-platform-config/RM-914-059S083/PLAT-files/ACPI/dsdt.dsl \
  extracted/acpi-or-platform-config/RM-914-059S083/panel-pcfg.xml
```

`iasl -v` reports version `20260408` in this workspace.

## Table Headers

| Table | Header Facts | Source Lines |
| --- | --- | --- |
| DSDT | Signature `DSDT`, length `0x0001149D` / `70813`, OEM `QCOMM`, table `MSM8930`, compiler `MSFT 04000000` | `dsdt.dsl:10-21` |
| SSDT | Signature `SSDT`, length `0x00000D24` / `3364`, OEM `NOKIA`, table `MSM8930`, compiler `MSFT 04000000` | `ssdt.dsl:10-21` |

## Display PCFG

The DSDT GPU `_ROM` method embeds `Name (PCFG, Buffer (0x1334))`; the buffer begins with XML and panel name `Teisko`.

| Fact | Source Lines |
| --- | --- |
| DSDT PCFG buffer starts in `\_SB.GPU0._ROM` | `dsdt.dsl:16140-16160` |
| Extracted XML path | `extracted/acpi-or-platform-config/RM-914-059S083/panel-pcfg.xml` |

Detailed panel facts are tracked in `notes/display.md`.

## Notable DSDT Devices

| Area | ACPI Device / HID | Source Lines | Notes |
| --- | --- | --- | --- |
| PMIC / abstract bus | `ABD` / `QCOM1200`, `PMIC` / `QCOM0A00`, `PM01` / `QCOM05C0` | `dsdt.dsl:25-69` | PMIC and ACPI bus plumbing. |
| Power/resource proxy | `PRXY` / `QCOM0812` | `dsdt.dsl:12803-12820` | Uses `\_SB.ABD` GenericSerialBus field. |
| GPU | `SGPU` / `QCOM_GPU` | `dsdt.dsl:16865-16870` | Separate from the `GPU0` PCFG-bearing display object. |
| Camera complex | `CAMP`, `CAMS`, `CAMG`, `VFE0`, `VPE` | `dsdt.dsl:17047-17174` | Camera/VFE resource blocks and dependencies. |
| TLMM GPIO | `GIO0` / `QCOM0500` | `dsdt.dsl:17194-17219` | GPIO controller resource block. |
| PMIC GPIO / power key | `PWIO` / `QCOM0D20` | `dsdt.dsl:17222-17249` | PMIC GPIO and power-key methods. |
| Button controller | `BTN0` / `QCOM0D60`, `PNP0C40` | `dsdt.dsl:17323-17397` | Resource buffer references `PWIO` and `PM01`. |
| GSBI inventory | `GSBI` / `QCOM0145` | `dsdt.dsl:17399-17505` | Lists GSBI bases `0x16000000` through `0x1A200000`, plus `0x12440000` and `0x12480000`. |
| I2C controllers | `I2C9`, `I2C3`, `IC12` / `QCOM0180` | `dsdt.dsl:17507-17574` | `IC12` is used by SSDT sensors. |
| SMEM/SMD/GPS | `SMEM` / `QCOM0F00`, `SMD0` / `QCOM0F10`, nested `GPS` / `QCOM_GPS` | `dsdt.dsl:17576-17652` | GPS is represented under SMD. |
| Riva WLAN/BT/FM | `RIVA` / `QCOM0E20`, nested `BTH0`, `QWLN`, `FMT0`, `WPXY` / `NOKIA_WLAN_PROXY` | `dsdt.dsl:17710-17801` | Riva reserved memory starts at `0x8F200000` with length `0x0500` units as represented by ACPI package. |
| Storage | `SDC1`, `SDC3` / `QCOM7002` | `dsdt.dsl:18048-18118` | `SDC1` has child `EMMC`, `_RMV` returns `Zero`; `SDC3` resource buffer includes `GIO0` pin `0x5E` / 94. |
| USB function | `UFN1` / `QCOM01C0` | `dsdt.dsl:18376-18440` | Resource block uses base `0x12500000`; has `_UBF` and `PHYC` methods. |
| Vibra | `VIB1` / `NOKIA_VIBRA_DIME` | `dsdt.dsl:21031-21043` | Nokia vibra device with empty resource template. |
| Touch | `TCH1` / `NOKIA_TOUCH` | `dsdt.dsl:21056-21150` | Depends on `PEP0`, `PRXY`, `I2C3`, and `GIO0`; resource buffer decodes to I2C address `0x4B`, `GpioInt` pin 11, and `GpioIo` pin 52. |
| Touch support | `ATTS` / `NOKIA_ATTS` | `dsdt.dsl:21152-21155` | Adjacent Nokia touch-related ACPI device. |

## Notable SSDT Devices

| Area | ACPI Device / HID | Source Lines | Notes |
| --- | --- | --- | --- |
| Accelerometer | `ACC1` / `KXTNK` | `ssdt.dsl:30-143` | Resource buffer references `IC12` and `GIO0`; rotation matrix is `1 0 0`, `0 1 0`, `0 0 -1`. |
| ALS candidate | `ALS1` / `QPDS_T900_ALS` | `ssdt.dsl:145-276` | `_STA` probes I2C address `0x39` on `\_SB.IC12`. |
| ALS candidate | `ALS2` / `LTR_554ALS_02_ALS` | `ssdt.dsl:279-357` | Resource buffer references `IC12` and `GIO0`; mode returns `0x01`. |
| Proximity candidate | `PRX1` / `QPDS_T900_PRX` | `ssdt.dsl:359-492` | `_STA` probes I2C address `0x39` on `\_SB.IC12`. |
| Proximity candidate | `PRX2` / `LTR_554ALS_02_PRX` | `ssdt.dsl:494-582` | Resource buffer references `IC12` and `GIO0`; mode returns `0x02`. |
| Nokia diagnostics | `NDLD`, `NREG`, `VIB2`, `NCPU`, `NEDD` | `ssdt.dsl:584-624` | Includes `ODDT_VIB` and `NOKI0B00`; likely diagnostics/test support. |

## Open Decode Work

1. Finish decoding ACPI GPIO flags, IRQ trigger/polarity, pull config, and wake bits before changing DTS.
2. Compare ACPI storage facts with the live GPT and current DTS, especially SDCC3 removable status and `GIO0` pin 94.
3. Decide whether SSDT ALS/PRX alternatives represent population variants or runtime probe fallbacks.
