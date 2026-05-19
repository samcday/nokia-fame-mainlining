# Research Index

This file stays small so agents can load the workspace map quickly. Detailed breadcrumbs live in `notes/*.md`.

When adding or changing a non-obvious register address, GPIO, regulator, partition offset, memory range, boot image layout value, panel command, protocol command, or similar magic value, update the relevant note in the same change.

## Topic Files

| Topic | File |
| --- | --- |
| Source hierarchy and provenance rules | `notes/source-trust.md` |
| Submodule/source inventory | `notes/prior-art-index.md` |
| Device facts and community hardware clues | `notes/hardware-inventory.md` |
| FFU download/extraction inventory | `notes/ffu-inventory.md` |
| GPT and partition facts | `notes/partitions.md` |
| Boot chain, ESP, UEFI, U-Boot route | `notes/boot-chain.md` |
| Lumia BootMgr/FlashApp/PhoneInfo protocol | `notes/bootmgr-protocol.md` |
| ACPI/DSDT/SSDT/platform config | `notes/acpi.md` |
| Display/panel/simplefb clues | `notes/display.md` |
| Touchscreen/touch-related clues | `notes/touch.md` |
| Regulators, GPIO, PMIC, and pinctrl clues | `notes/regulators-gpio.md` |
| Safe live-device observations | `notes/live-device-inventory.md` |

## Status Files

| File | Purpose |
| --- | --- |
| `README.md` | Quick human status and common commands. |
| `STATUS.md` | Current implementation state and next work. |
| `AGENTS.md` | Workspace rules and safety constraints. |
