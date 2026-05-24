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

## MDP4 / MMCC Footswitch Bring-Up Dead-End (2026-05-24)

Attempted MDP4 bring-up in `linux/` (MDP4 -> DSI -> Teisko). DSI host version
reads fine, but **every CPU read of the MDP register block at `0x05100000`
stalls the bus**, in the kernel *and* in bare U-Boot. Root cause is an
incomplete/unproven MDP power (footswitch/GFS) + clock model, not a Linux bug.
Decision: stop fighting the kernel MDP4 driver + custom footswitch; implement
MDP4 in U-Boot first to get a clean, proven reference (ideally a live
framebuffer), then return to the kernel.

### Register map (verified)

| Block | Addr | Source |
| --- | --- | --- |
| MMCC base | `0x04000000` | `linux/arch/arm/boot/dts/qcom/qcom-msm8227.dtsi` mmcc@4000000; LK `community/android4lumia-lk-msm8227/platform/msm8960/include/platform/iomap.h:93` |
| DSI host (works) | `0x04700000` | dtsi dsi@4700000; LK iomap.h:95 |
| MDP4 base | `0x05100000` | dtsi mdp@5100000 `reg=<0x05100000 0xf0000>`; LK iomap.h:115 `MDP_BASE` |
| MDP4 VERSION | `+0x0`, expect `0x04030705` | working `samsung-expressltexx` MSM8930 sibling `devmem2 0x05100000` (user, 2026-05-24). NB earlier `0x0403xxxx` "DISPLAY_STATUS" note was a red herring. |

MMCC MDP control/clock/reset registers (`linux/drivers/clk/qcom/mmcc-msm8960.c`):

| Field | MMCC off / bit | Source line |
| --- | --- | --- |
| GFS_CTL (`MDP_PD_CTL_REG`) | `0x0190`; DELAY[4:0], CLAMP=b5, ENABLE=b8, RETENTION=b9 | `mmcc-msm8960.c:3120-3125` |
| mdp_clk | en `0x00c0` b0 / halt `0x01d0` b10 | `:1346-1362` |
| mdp_ahb_clk | en `0x0008` b10 / halt `0x01dc` b11 | `:2639-2650` |
| mdp_axi_clk | en `0x0018` b23, hwcg b16 / halt `0x01d8` b8 | `:1972-1985` |
| mdp_lut_clk | en `0x016c` b0 / halt `0x01e8` b13 | `:1364-1380` |
| mdp_src (banked RCG) | ns `0x00d0`, md `0x00c4`/`0x00c8`, bank `0x00c0`; tbl has 200M & 266667M | `:1282-1333` |
| SW_RESET_AHB2 / ALL / AXI / AHB / CORE | `0x0200` / `0x0204` / `0x0208` / `0x020c` / `0x0210` | `:2856-2868`; LK clock.h:196-200 |
| MPD_AXI_RESET (MDP AXI port) | `0x0208` b13 | `mmcc-msm8960.c:2858` ("MPD" typo); LK `clock.c:596-597` |
| MDP_AHB_RESET / MDP_RESET | `0x020c` b3 / `0x0210` b21 | `:2895,2907`; LK `clock.c:656-657` |

LK references (`community/android4lumia-lk-msm8227/platform/msm8960`): `mdp_clk`
runs at **200 MHz** + `lut_mdp` (`acpuclock.c:142-150`); `mdp_axi_clk` owns
`SW_RESET_AXI` b13, `mdp_clk` owns `SW_RESET_CORE` b21 (`clock.c:592-672`); LK
does **not** manage a footswitch (no GFS poke in `platform/msm8960`). LK relies
on SBL for power and **does not achieve a working display on fame** (user) -- so
LK is style reference only, not a proven sequence.

### Live U-Boot probe over UART (`/dev/ttyUSB1`, 115200 8N1, `md`/`mw`)

U-Boot console output pads each char with 3 NUL bytes (MSM UART quirk); strip
with `tr -d '\000'`. Cold SBL state, before any kernel:

| Reg | Cold value | Meaning |
| --- | --- | --- |
| GFS_CTL `0x04000190` | `0x31f` | ENABLE+RETENTION set, CLAMP clear |
| mdp_clk en `0x040000c0` b0 | 0 | core clock OFF |
| mdp_ahb en `0x04000008` b10 | 0 | reg-iface clock OFF |
| mdp_axi en `0x04000018` b23 | 1 | bus clock ON |
| SW_RESET AXI/AHB/CORE | 0 | not in reset |

So **SBL sets the footswitch enable bit and `mdp_axi`, but leaves `mdp_clk` and
`mdp_ahb` off.** Reading `0x05100000` cold hangs U-Boot (no AHB clock).

Experiment that broke the hang (U-Boot): `mw 0x04000008 <|=b10>` to start
`mdp_ahb`, then cycle the GFS with the clock running --
`mw 0x04000190 0x3f` (collapse: clamp on, enable off) ->
`0x13f` (enable on) -> `0x11f` (unclamp). After that, `md 0x05100000`
**returned without stalling the bus for the first time**. Values were unstable
garbage (`0x27391300`, `0x241f00c8`, `0x80850598`, ...) because `mdp_clk` (core)
was still off, so the register file is unclocked/floating -- but the AHB slave
*acked*, proving power finally reached the MDP island. Conclusion: SBL's enable
bit is set with no clock, so the power-on never ramps; nothing re-triggers the
off->on transition, so the core stays unpowered and reads stall.

### The kernel contradiction (unresolved)

Kernel HACK `170d1f05` (linux) redoes that exact GFS handshake in
`read_mdp_hw_revision()` (`linux/drivers/gpu/drm/msm/disp/mdp4/mdp4_kms.c`)
after `mdp4_enable()`. boot-18: `GFS_CTL before 0x11f after 0x11f`, resets
clear, clocks `mdp 1/0 ahb 1/0 axi 1/0 lut 1/0` (all running) -- and the readl
**still hangs**. So the *same* handshake that made the bus respond in U-Boot
does not in the kernel. The only material difference at the read: the kernel
additionally has `mdp_clk` (at **266 MHz**) and `mdp_lut` running.

Open questions to resolve in the U-Boot effort:

1. Is `mdp_clk` = 266 MHz invalid for MSM8227? LK uses 200 MHz, and
   `mdp4_kms.c` itself comments that non-apq8064 parts cap at 200 MHz. A bad
   core-clock rate may wedge MDP register access even when `halt=0`.
2. Does the GFS power-up need the *core* clock toggling (not just AHB), and does
   having a *bad* core clock on during the read make it worse than off?
3. The custom MDP power domain (`mmcc-msm8960.c:3120-3362`,
   `mmcc_msm8960_mdp_pd_*`) is non-upstream and unproven: it never polls a
   power-on ack, its GFS bit model may be incomplete, and the genpd handshake
   ran at MMCC-probe time before `mdp_clk` had a valid rate. This is the prime
   suspect and the thing to get right in U-Boot first.

### Kernel HACK commit trail (linux submodule, branch `nokia-fame`)

All diagnostic; only the DSI one fixed a real bug. To be reworked/unwound when
the proven sequence exists:

| Commit | What | Verdict |
| --- | --- | --- |
| `09ede3fe` | DSI: enable APQ8064 config clocks before version read | real fix (DSI version reads) |
| `387c0e01` | trace MDP4 bring-up hang | instrumentation |
| `a53b254b` | trace MDP4 clock enable hang | instrumentation |
| `b67c1e4b` | dump MMCC MDP reset/clock state | instrumentation |
| `327a71e1` | stop power-cycling MDP in PD selftest | partial; not the fix |
| `41a1ffda` | deassert MPD_AXI_RESET before read | no-op (reset already clear) |
| `170d1f05` | redo GFS power-up handshake with clocks on | works in U-Boot, **still hangs in kernel** |

NB: these HACK commits carry `Signed-off-by: Sam Day` (mirroring the earlier
`Assisted-by: OpenCode` commit), but AGENTS.md:54 says assistants must not add
`Signed-off-by` to kernel commits. Flag for cleanup before any upstreamable
patch; left as-is on the throwaway bring-up branch for now.

## Next Work

1. Implement MDP4 + DSI + Teisko in U-Boot: prove the MDP power-up (footswitch
   GFS at MMCC `0x0190`) and the MDP/AHB/AXI/LUT clock sequence (try `mdp_clk`
   at 200 MHz first, not 266), then read a stable `VERSION = 0x04030705` and
   ideally paint a framebuffer. Use that as the reference sequence.
2. Carry the proven sequence back to the kernel: most likely rework
   `mmcc_msm8960_mdp_pd_*` so the GFS power-on runs with the MDP clocks
   enabled and at a valid rate, then unwind the MDP4 HACK commits above.
3. Re-test simple framebuffer only from a boot path that proves the display
   buffer is live and does not overlap the ARM kernel load/decompression window.
4. Confirm panel reset GPIO 58 against stock-FFU `DSI_PANEL_RESET` (DSDT
   resource 15) to reach Tier A.
5. Translate PCFG timings and DSI values into a Linux panel description only
   after reset/backlight/power sequencing is credible.
