# Touch

Touch is not enabled in the current mainline Fame DTS.

## Current Clues

| Source | Claim | Trust |
| --- | --- | --- |
| Android4Lumia README | Touch controller is Synaptics | C |
| Android4Lumia kernel config | `CONFIG_TOUCHSCREEN_SYNAPTICS_I2C_RMI*` | C |
| Fame DTS disabled sketch | Synaptics RMI4 at I2C `0x4b`, IRQ MSM GPIO11, reset MSM GPIO52, supplies PM8038 L9/LVS2 | C, disabled |

## Risks

The DTS touch node is commented out. Do not enable it until bus, address, IRQ polarity, reset GPIO, and power rails are validated against FFU/platform data or hardware probing.

## Next Work

1. Search FFU/ACPI/platform config for Synaptics, I2C resources, GPIO11/GPIO52, and regulator hints.
2. Check Android4Lumia kernel source for Fame-specific RMI4 platform data.
3. Enable only after power rails and IRQ/reset lines are credible.
