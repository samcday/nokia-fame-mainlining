# Touch

Touch is not enabled in the current mainline Fame DTS.

## Current Clues

| Source | Claim | Trust |
| --- | --- | --- |
| Android4Lumia README | Touch controller is Synaptics | C |
| Android4Lumia kernel config | `CONFIG_TOUCHSCREEN_SYNAPTICS_I2C_RMI*` | C |
| Fame DTS disabled sketch | Synaptics RMI4 at I2C `0x4b`, IRQ MSM GPIO11, reset MSM GPIO52, supplies PM8038 L9/LVS2 | C, disabled |
| Stock FFU DSDT | `TCH1` has `_HID "NOKIA_TOUCH"`, depends on `I2C3` and `GIO0`, and its resource buffer decodes to I2C address `0x4B`, `GpioInt` pin 11, and `GpioIo` pin 52 | A, GPIO flags pending |

## Stock FFU ACPI Breadcrumbs

| Fact | Source Lines |
| --- | --- |
| `TCH1` device with `_HID "NOKIA_TOUCH"` | `dsdt.dsl:21056-21059` |
| Dependencies include `PEP0`, `PRXY`, `I2C3`, and `GIO0` | `dsdt.dsl:21060-21066` |
| `_CRS` serial-bus descriptor decodes to I2C address `0x4B` on `\_SB.I2C3` | `dsdt.dsl:21067-21075` |
| `_CRS` GPIO descriptors decode to `GpioInt` pin 11 and `GpioIo` pin 52 on `\_SB.GIO0` | `dsdt.dsl:21075-21085` |
| Power-state methods write `\_SB.TCH1` state through `PRXY.FLD0` | `dsdt.dsl:21088-21149` |
| Adjacent `ATTS` device has `_HID "NOKIA_ATTS"` | `dsdt.dsl:21152-21155` |

## Risks

The DTS touch node is commented out. The FFU strongly corroborates the I2C address and GPIO pin numbers, but do not enable it until the ACPI GPIO flags and power rails are validated against FFU/platform data or hardware probing.

## Next Work

1. Finish decoding `TCH1._CRS` GPIO flags to confirm IRQ polarity/trigger, reset behavior, pulls, and wake bits.
2. Search ACPI/PLAT/EFIESP for regulator hints for touch rails; the current `pm8038_l9` / `pm8038_lvs2` mapping remains from the disabled DTS sketch.
3. Check Android4Lumia kernel source for Fame-specific RMI4 platform data only as a lower-trust comparison.
4. Enable only after power rails and IRQ/reset lines are credible.
