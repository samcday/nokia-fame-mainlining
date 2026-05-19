# Regulators And GPIO

Initial regulator/GPIO data comes from the msm8227-mainline Fame DTS and is not yet hardware-validated in this workspace.

## PMIC And Supplies

| Consumer | Supply Mapping | Source | Trust |
| --- | --- | --- | --- |
| eMMC SDCC1 `vmmc` | `pm8038_l5` | Fame DTS | C |
| eMMC SDCC1 `vqmmc` | `pm8038_l11` | Fame DTS | C |
| SDCC3 `vmmc` | `pm8038_l6` | Fame DTS | C |
| SDCC3 `vqmmc` | `pm8038_l22` | Fame DTS | C |
| USB HS PHY 3.3 V | `pm8038_l3` | Fame DTS | C |
| USB HS PHY 1.8 V | `pm8038_l4` | Fame DTS | C |
| WCNSS core | `pm8038_s1` | Fame DTS | C |
| WCNSS mx | `pm8038_l24` | Fame DTS | C |
| WCNSS px/io | `pm8038_l11` | Fame DTS | C |
| Synaptics VDD | `pm8038_l9` | Disabled Fame DTS sketch | C |
| Synaptics VIO | `pm8038_lvs2` | Disabled Fame DTS sketch | C |

## GPIO Clues

| Function | GPIO | Source | Trust |
| --- | --- | --- | --- |
| Volume up | PM8038 GPIO3 | Fame DTS | C |
| Volume down | PM8038 GPIO8 | Fame DTS | C |
| Camera snapshot | PM8038 GPIO10 | Fame DTS | C |
| Camera focus | PM8038 GPIO11 | Fame DTS | C |
| Touch IRQ | MSM GPIO11 | Disabled Fame DTS sketch | C |
| Touch reset | MSM GPIO52 | Disabled Fame DTS sketch | C |
| WLAN pins | MSM GPIO84-88 | Fame DTS | C |
| BT pins | MSM GPIO28, GPIO29, GPIO83 | Fame DTS | C |

## Stock FFU ACPI Breadcrumbs

| Function | FFU/ACPI Clue | Source | Trust |
| --- | --- | --- | --- |
| TLMM GPIO controller | `GIO0` HID `QCOM0500` | `dsdt.dsl:17194-17219` | A |
| PMIC GPIO / power-key controller | `PWIO` HID `QCOM0D20` | `dsdt.dsl:17222-17249` | A |
| Button controller | `BTN0` HID `QCOM0D60`, CID `PNP0C40`, resource buffer references `PWIO` and `PM01` | `dsdt.dsl:17323-17397` | A, resource decode pending |
| SDCC3 card/resource GPIO | `SDC3` resource buffer includes `GIO0` pin 94 | `dsdt.dsl:18088-18118` | A, GPIO flags pending |
| Touch bus/GPIO shape | `TCH1` depends on `I2C3` and `GIO0`; resource buffer decodes to I2C address `0x4B`, `GpioInt` pin 11, and `GpioIo` pin 52 | `dsdt.dsl:21056-21085` | A, GPIO flags pending |

Do not overwrite DTS GPIO flags directly from raw `_CRS` bytes. Decode and verify ACPI flags, pulls, trigger type, polarity, and wake behavior first.

## Known DTS Issues

`qcom-msm8227-nokia-fame.dts` currently uses `drive-strengh` instead of `drive-strength` in SDCC pinctrl groups. Fix this before treating SDCC pinctrl as configured.
