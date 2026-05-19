# Display

Display is not enabled in the current mainline Fame DTS. First goal is either preserve/describe a firmware framebuffer or extract panel configuration for eventual MDP/DSI bring-up.

## Current Clues

| Source | Claim | Trust |
| --- | --- | --- |
| Android4Lumia README | 4.0 inch 800x480 Orise-based display | C |
| Android4Lumia kernel config | `CONFIG_FB_MSM_MIPI_ORISE_VIDEO_FWVGA_PT_PANEL=y` | C |
| pmaports deviceinfo | `deviceinfo_screen_width=480`, `deviceinfo_screen_height=800` | C |
| Mainline4Lumia script | Lumia DSDT may contain `Name (PCFG, ...)` panel XML | D method |
| Stock FFU DSDT | Embedded `PCFG` XML names the panel `Teisko` and describes a 480x800 24bpp DSI panel | A |

## Stock FFU PCFG

Source files:

| Artifact | Path |
| --- | --- |
| Decompiled DSDT | `extracted/acpi-or-platform-config/RM-914-059S083/PLAT-files/ACPI/dsdt.dsl` |
| Extracted PCFG XML | `extracted/acpi-or-platform-config/RM-914-059S083/panel-pcfg.xml` |

Breadcrumbs:

| Fact | Source Lines |
| --- | --- |
| `Name (PCFG, Buffer (0x1334))` starts in DSDT GPU `_ROM` | `dsdt.dsl:16140-16160` |
| Panel name and description | `panel-pcfg.xml:2-3` |
| Active timing | `panel-pcfg.xml:41-62` |
| DSI interface | `panel-pcfg.xml:71-87` |
| Commented DSI init/term/reset clues | `panel-pcfg.xml:88-112` |
| Backlight configuration | `panel-pcfg.xml:113-118` |

Panel identity:

| Field | Value |
| --- | --- |
| `PanelName` | `Teisko` |
| `PanelDescription` | `Teisko DSI Panel (480x800 24bpp)` |

Active timing:

| Field | Value |
| --- | --- |
| Pixel clock | `52598700` Hz |
| Horizontal active | `480` |
| Horizontal front porch | `23` |
| Horizontal back porch | `16` |
| Horizontal sync pulse | `8` |
| Vertical active | `800` |
| Vertical front porch | `7` |
| Vertical back porch | `2` |
| Vertical sync pulse | `2` |
| Data polarity | Not inverted |
| Vsync polarity | Not inverted |
| Hsync polarity | Not inverted |

DSI configuration:

| Field | Value |
| --- | --- |
| Interface type | `9` |
| Interface color format | `3` |
| DSI channel ID | `2` |
| DSI virtual ID | `0` |
| DSI color format | `36` |
| DSI traffic mode | `1` |
| DSI lanes | `2` |
| DSI refresh rate | `0x3C0000` |
| DSI host lane mapping | `1` |

The PCFG XML comments include possible init and terminate byte sequences, but they are inside an XML comment in the extracted blob. Treat them as a clue until matched against driver expectations or another source.

Backlight configuration:

| Field | Value |
| --- | --- |
| Backlight type | `3` |
| Steps | `100` |
| Default | `80` percent |
| Low power | `40` percent |

## UEFI Framebuffer

Source files:

| Artifact | Path |
| --- | --- |
| Decompiled DSDT | `extracted/acpi-or-platform-config/RM-914-059S083/PLAT-files/ACPI/dsdt.dsl` |
| BGRT table | `extracted/acpi-or-platform-config/RM-914-059S083/PLAT-files/ACPI/bgrt.acp` |

Breadcrumbs:

| Fact | Source Lines |
| --- | --- |
| `GPU0._CRS` resource buffer contains display/GPU resources | `dsdt.dsl:13150-13180` |
| `GPU0.RESI` labels resource 14 as `UEFI_FRAME_BUFFER` and resource 15 as `DSI_PANEL_RESET` | `dsdt.dsl:13183-13294` |
| Decoding resource order maps `UEFI_FRAME_BUFFER` to `0x80400000` size `0x00400000` | `dsdt.dsl:13150-13294` |
| BGRT table points at image address `0x80c00000` | `bgrt.acp` bytes `0x24-0x2b` |

Initial Linux simple-framebuffer assumptions:

| Field | Value | Confidence |
| --- | --- | --- |
| Base | `0x80400000` | A, decoded from DSDT resource order |
| Size | `0x00400000` | A, decoded from DSDT resource order |
| Width | `480` | A, PCFG active timing |
| Height | `800` | A, PCFG active timing |
| Stride | `1920` | B, inferred from 480 pixels at 32 bpp |
| Format | `a8r8g8b8` | B, inferred from Qualcomm/UEFI GOP BGRA convention and adjacent Lumia SimpleFbDxe |

## Next Work

1. Determine whether the unlocked UEFI path leaves a usable framebuffer and whether Linux can consume it as `simple-framebuffer`.
2. Decode panel supply, reset, and backlight resources from ACPI or another tier-A source before enabling MDP/DSI.
3. Translate PCFG timings and DSI values into a Linux panel description only after reset/backlight/power sequencing is credible.
