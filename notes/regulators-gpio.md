# Regulators And GPIO

Initial regulator/GPIO data comes from the msm8227-mainline Fame DTS and is not yet hardware-validated in this workspace.

## PMIC And Supplies

| Consumer | Supply Mapping | Source | Trust |
| --- | --- | --- | --- |
| eMMC SDCC1 `vmmc` | `pm8038_l5` | Fame DTS sketch; PM8038 L5 RPM resource support cross-checked below | C |
| eMMC SDCC1 `vqmmc` | `pm8038_l11` | Fame DTS sketch; PM8038 L11 RPM resource support cross-checked below | C |
| SDCC3 `vmmc` | `pm8038_l6` | Fame DTS | C |
| SDCC3 `vqmmc` | `pm8038_l22` | Fame DTS | C |
| USB HS PHY 3.3 V | `pm8038_l3` | Fame DTS sketch; PM8038 L3 RPM resource support cross-checked below | C |
| USB HS PHY 1.8 V | `pm8038_l4` | Fame DTS sketch; PM8038 L4 RPM resource support cross-checked below | C |
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

## MSM8930/PM8038 RPM Breadcrumbs

| Fact | Source | Trust |
| --- | --- | --- |
| MSM8930 RPM resource table includes PM8038 L3/L4/L5/L11 with active resource IDs 106/108/110/122, selectors 38/39/40/46, and status selectors 47/49/51/63. | `community/android4lumia-kernel-msm8x27/arch/arm/mach-msm/devices-8930.c:135-143`, `community/android4lumia-kernel-msm8x27/arch/arm/mach-msm/include/mach/rpm-8930.h:72-80,238-255,455-472` | C |
| The Samsung Express MSM8930 branch ports those same PM8038 resources into mainline-style RPM/regulator drivers and supports PM8038 `s4`, `l3`, `l4`, `l5`, and `l11`. | `samsung-expressltexx:drivers/mfd/qcom_rpm.c:341-347`, `samsung-expressltexx:drivers/regulator/qcom_rpm-regulator.c:918-924,950-958` | E |
| The Samsung Express board wires USB HS PHY supplies to PM8917 L4/L3 and supplies its board-specific ULPI init sequence from the board DTS. Fame keeps its ACPI-derived ULPI init sequence instead of copying Express values. | `samsung-expressltexx:arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:519-528`, `notes/hardware-inventory.md:35-36` | E/A |

Do not enable SDCC3 supplies from the old Fame DTS sketch yet. PM8038 L6/L22 are not covered by the current Express-derived RPM regulator support and SDCC3 card-detect GPIO flags remain undecoded from ACPI.

The current Fame DTS only instantiates PM8038 RPM regulators needed for first
boot cleanup: L3/L4 for USB HS PHY and L5/L11 for SDCC1/eMMC. These are
deliberately limited to the PM8038 resources now supported by the local
Express-derived RPM/regulator driver patch.

## Known DTS Issues

The old Fame DTS sketch used `drive-strengh` instead of `drive-strength` in
SDCC pinctrl groups. The minimal first-boot DTS does not carry those pinctrl
groups; fix the typo before reintroducing SDCC pinctrl.
