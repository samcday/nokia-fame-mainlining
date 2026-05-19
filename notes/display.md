# Display

Display is not enabled in the current mainline Fame DTS. First goal is either preserve/describe a firmware framebuffer or extract panel configuration for eventual MDP/DSI bring-up.

## Current Clues

| Source | Claim | Trust |
| --- | --- | --- |
| Android4Lumia README | 4.0 inch 800x480 Orise-based display | C |
| Android4Lumia kernel config | `CONFIG_FB_MSM_MIPI_ORISE_VIDEO_FWVGA_PT_PANEL=y` | C |
| pmaports deviceinfo | `deviceinfo_screen_width=480`, `deviceinfo_screen_height=800` | C |
| Mainline4Lumia script | Lumia DSDT may contain `Name (PCFG, ...)` panel XML | D method |

## Next Work

1. Extract FFU/ESP/ACPI artifacts.
2. Find/decompile DSDT/SSDT if present.
3. Try `acpi_panel_extractor.py` for PCFG XML.
4. Determine whether the unlocked UEFI path leaves a usable framebuffer and whether Linux can consume it as `simple-framebuffer`.
5. Delay real MDP/DSI panel driver work until panel commands and supplies have high-trust provenance.
