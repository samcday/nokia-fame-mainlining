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

The raw U-Boot fastboot Linux path intentionally does not enable this as a
`simple-framebuffer` node yet. A 2026-05-22 hardware boot attempt with an
Android boot-image v2 DTB reached U-Boot's FDT handoff, then failed while
allocating the kernel at `0x80208000` because the DTB-reserved framebuffer at
`0x80400000..0x807fffff` overlaps the ARM zImage low load/decompression window.
The relevant U-Boot fixed-address LMB allocation is `u-boot/boot/bootm.c:706-716`.
Keep the framebuffer facts above for later UEFI/simpledrm experiments, but do
not reserve that memory in `qcom-msm8227-nokia-fame.dts` for the first UART/UDC
bring-up path.

## Panel Power And Reset Decode

Decoded from the Android4Lumia fame downstream (`lineage_fame_defconfig` ->
`MACH_MSM8627` -> `board-8930-display.c`, which carries the Orise FWVGA panel),
cross-checked against the `samsung-expressltexx` MSM8930 effort and the mainline
msm DSI regulator model. The stock-FFU `DSI_PANEL_RESET` (DSDT GPU0 resource 15,
still undecoded) would upgrade the reset GPIO from C to A.

| Fact | Value | Source | Trust |
| --- | --- | --- | --- |
| Display board file for fame | `board-8930-display.c` (mipi_video_orise_fwvga) | A4L `lineage_fame_defconfig`=MACH_MSM8627; `arch/arm/mach-msm/Makefile` board-8930-all-objs | C |
| Panel reset GPIO | MSM TLMM GPIO 58, active low (`disp_rst_n`), 2mA, no pull | A4L `board-8930-display.c:106,124-138` | C |
| Reset release pulse | high, 2ms, low, 2ms, high | A4L `board-8930-display.c:129-138` | C |
| `dsi_vdda` (DSI PHY analog) | 1.2V -> PM8038 **L2** | A4L `board-8930-display.c:160-173`; `board-8930-regulator-pm8038.c:34-42` (VREG_CONSUMERS L2) | C |
| `dsi_vdc` (panel VDD / mainline `avdd`) | 2.8-2.85V -> PM8038 **L8** | A4L `board-8930-display.c:176-190,243-245`; `board-8930-regulator-pm8038.c:63-66` (VREG_CONSUMERS L8) | C |
| `dsi_vddio` (panel/DSI IO) | 1.8V -> PM8038 **L11** (already always-on in Fame DTS) | A4L `board-8930-display.c:193-207`; `board-8930-regulator-pm8038.c:103-124` (VREG_CONSUMERS L11) | C |
| DSI data lane map | `data-lanes = <1 2>` (downstream dlane_swap=1; PCFG host lane mapping 1) | A4L + PCFG above | C |

Mainline supply attachment (`drivers/gpu/drm/msm/dsi/dsi_cfg.c` `apq8064_dsi_regulators`;
`dsi/phy/dsi_phy_28nm_8960.c` `dsi_phy_28nm_8960_regulators`):

- `dsi@4700000`: `vdda-supply` (1.2V, L2), `avdd-supply` (3.0V, L8), `vddio-supply` (1.8V, L11)
- `phy@4700200`: `vddio-supply` (1.8V, L11)
- `panel@0`: reset-gpios only; panel VDD arrives via the DSI host `avdd`, mirroring the
  Express AMS452GP32 panel node (no panel-local supply phandle).

The mainline DSI host enables `vdda`/`avdd`/`vddio` before calling the panel's `prepare()`,
so the panel driver only sequences reset + sends the Teisko init commands.

## Next Work

1. Re-test simple framebuffer only from a boot path that proves the display buffer is live and does not overlap the ARM kernel load/decompression window.
2. Confirm panel reset GPIO 58 against stock-FFU `DSI_PANEL_RESET` (DSDT resource 15) to reach Tier A.
3. Translate PCFG timings and DSI values into a Linux panel description only after reset/backlight/power sequencing is credible.
