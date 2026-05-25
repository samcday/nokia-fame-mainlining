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

## Teisko DSI Backlight

2026-05-25 bring-up breadcrumb: the downstream Orise panel driver has a DSI-native
backlight path rather than a board-level PWM/GPIO backlight. It defines
`write_ctrl_display` as `0x53 0x24` and `write_display_brightness` as `0x51 0x80`
in `community/android4lumia-kernel-msm8x27/drivers/video/msm/mipi_orise.c:188-189`.
The Teisko on-sequence sends exit sleep, `0xff 0x78`, address mode `0x36 0x00`,
control display `0x53 0x24`, and display on at
`community/android4lumia-kernel-msm8x27/drivers/video/msm/mipi_orise.c:1014-1038`.
The downstream backlight callback updates byte 1 of `write_display_brightness`,
switches TX power mode to high-speed, sends the brightness command, then returns
to low-power mode at
`community/android4lumia-kernel-msm8x27/drivers/video/msm/mipi_orise.c:1176-1205`.

The mainline `panel-nokia-teisko` driver therefore registers a raw DSI backlight
with default brightness `0x80`, sends one-byte DCS `0x51 <level>` in high-speed
mode after display-on, and follows it with DCS `0x53 0x24` to enable brightness
control and the backlight bit.

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
| pll2 / MM_PLL1 | mode `0x031c`, status `0x0334` b16 | `:50-52`; LK `clock.h:128-129` |
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

## MDP4 Register Access CRACKED (2026-05-24, boot-21)

The kernel MDP4 path now reads the version and comes fully up -- the U-Boot
pivot above was overtaken by solving it directly in the kernel. The hang was
two stacked problems:

1. **Power:** SBL leaves the GFS enable bit set (`MDP_PD_CTL=0x31f`) but never
   ramps power (no off->on transition, so the set ENABLE bit is a "fake on").
   A real GFS cycle -- collapse `0x3f` -> enable `0x13f` -> unclamp `0x11f` --
   with clocks running delivers power. Proven in U-Boot: without it a read of
   `0x05100000` hangs; with it the slave responds.
2. **Core clock:** `mdp_clk` at 200 and 266 MHz (both `P_PLL2` in
   `clk_tbl_mdp`) hang the read identically; PLL2 (mmcc-internal, brought up
   on demand) never locks on fame. Running `mdp_clk` from `P_PXO` (27 MHz) was
   the fix. The reset bracket (assert/deassert CORE/AXI/AHB around enable) made
   no observable difference -- it can be dropped.

boot-21 (linux `8daf5173`, `mdp4_kms.c max_clk = 27000000`): `raw MDP4 version
0x4030705` -> `MDP4 version v4.3`, `[drm] Initialized msm 1.13.0 ... minor 0`,
`fb0` registered. Matches the working samsung-expressltexx VERSION exactly.

Current state (kernel runs, no hang): scanout is unhappy --
`[drm:mdp4_irq_error_handler] *ERROR* errors: 00000100` loops, `vblank time
out, crtc=crtc-0`, and `fb0: sys_imageblit: framebuffer is not in virtual
address space`. 27 MHz is a *diagnostic* core rate, far too slow to feed the
480x800 pipeline (pixel clock ~28-52 MHz), so underflow (err 0x100) and absent
vblank are the expected next problems -- not the MDP-access blocker.

MDP4 HACK commit trail (linux branch `nokia-fame`, on top of the earlier
diagnostics `09ede3fe`..`170d1f05`): `24ac55b0` add reset bracket (no-op),
`86fdbb6f` try 200 MHz (still hung), `8daf5173` PXO 27 MHz (**works**).

## PLL2 (MM_PLL1) Won't Lock -- MDP Runs From PLL8 (2026-05-24, boot-22)

boot-21's "PLL2 never locks" was a hypothesis; boot-22 proved it and found the
likely reason. Live probing via `fastboot oem run`/`oem console` (`md`/`mw`,
device `7cda982`) plus an in-kernel lock-poll settled it:

- PLL2's L/M/N/config ARE correctly programmed by SBL for **800 MHz**: MMCC
  `0x031c` mode, `0x0320` L=0x1d(29), `0x0324` M=0x11(17), `0x0328` N=0x1b(27),
  `0x032c` config=`0x00c20000` (vco `0x2<<16`, mn_ena BIT22, main_out BIT23) --
  matches upstream `pll15_config` bit-for-bit. But mode=0 (left disabled).
- Enabling it (BYPASSNL|RESET_N|OUTCTRL), both enable orders, never sets the
  lock bit (status `0x0334` bit16). U-Boot: 0 after >100 ms. In-kernel (boot-22,
  helper polled bit16 for 500 us): `lock=0` (status 0x0->0x1, bit0 only). So it
  is NOT a U-Boot reference/power starvation artefact.
- Positive control: **PLL8** (GCC `0x903158`) reads `0x00010001` -- bit16 LOCKED
  (L=14 -> 384 MHz, canonical). So lock-detect works; PLL2 genuinely won't lock.

Neither mainline (`mmcc-msm8960.c` configures only pll15 in probe) nor fame's
downstream (`clock-8960.c` `pll2_clk` = bare mode_reg, 800 MHz) carries PLL2
bring-up data -- both defer to the bootloader. Our raw-U-Boot/SBL path doesn't
fully bring MM_PLL1 up (likely the `TEST_CTL` `0x0330` VCO calibration, left 0),
and we don't have Nokia's value.

**Conclusion:** msm8227 is a low-end part that likely does not fit/use MM_PLL1.
The msm8960 driver's 160-266 MHz MDP rates (all P_PLL2) are inapplicable here;
MDP must run from **PLL8** (the `<=128 MHz` rows of `clk_tbl_mdp`, externally
voted + proven locked). `mdp4_kms.c max_clk` is now `128000000` (commit
`3e69030c`); 128 MHz >> the ~33 MHz this 480x800 panel needs. **Test boot
pending a free device** (another session holds `7cda982`).

**Golden-state cross-check (planned, Sam):** reflash unlocked UEFI, chain
U-Boot in EFIESP where the display is lit, then dump the *working* MDP clock
tree to confirm what it actually drives MDP from (expect PLL8, PLL2 unlocked):
`mdp_src` RCG -- `md.l 0x040000c0`(bank) `0x040000c4`/`0x040000c8`(md)
`0x040000d0`(ns, src-sel+div); PLL mode+status PLL8 `0x903140`/`0x903158`,
PLL2 `0x0400031c`/`0x04000334`, PLL15 `0x04000338`/`0x04000350`; footswitch
`0x04000190`; DSI PLL (offsets TBD on the day).

## Golden-State Dump + Pre/Post-UEFI Comparison (golden read 2026-05-24)

**This SUPERSEDES the PLL8 conclusion above.** Sam reflashed unlocked UEFI and
chained U-Boot in EFIESP where the **display is lit**; dumped over UART
(`/dev/ttyUSB1`). The working display drives MDP **from PLL2** -- so boot-22's
"PLL2 won't lock" was a misread of status bit16, and the PLL8 pivot (kernel
`3e69030c`, workspace `9b97cfa`) looked like it needed reconsidering -- but
boot-23 then confirmed PLL8 works end-to-end (MDP to userspace, `0x100`/vblank
cleared), so PLL8 was **kept** as the settled MDP clock (see Next Work item 1).
The firmware happens to use PLL2, but we don't need to.

| Register | Pre-UEFI (raw U-Boot fastboot, SBL) | Post-UEFI (golden, display LIT) |
| --- | --- | --- |
| PLL2 mode `0x031c` | `0x0` disabled; my manual enable -> `0x7` | `0x00000007` (BYPASSNL+RESET_N+OUTCTRL) |
| PLL2 L/M/N `0x320/4/8` | `0x1d`/`0x11`/`0x1b` (29/17/27 = 800 MHz) | `0x1d`/`0x11`/`0x1b` (identical) |
| PLL2 config `0x032c` | `0x00c20000` | `0x00c20000` (identical) |
| PLL2 TEST_CTL `0x0330` | `0x0` | `0x0` (identical) |
| PLL2 status `0x0334` | `0x0`; after manual enable -> `0x1` (bit0; **bit16=0**) | `0x00000001` (bit0; **bit16=0**) |
| mdp_src bank `0x00c0` | *not read (gap)* | `0x80ff08a5` (en bit2=1, bank-sel bit11=1 -> bank1) |
| mdp_src md1 `0x00c8` | *not read (gap)* | `0x000001fb` |
| mdp_src ns `0x00d0` | *not read (gap)* | `0x003f0001` (bank1 src-sel bits[1:0]=1 = **P_PLL2**) |
| footswitch `0x0190` | *not read in raw (gap)*; boot-22 kernel-entry was `0x11f` | `0x0000031f` (ENABLE+RETENTION, CLAMP clear) |
| PLL8 mode `0x903140` | `0x0010bf00` (FSM) | `0x0010bf00` (identical) |
| PLL8 status `0x903158` | `0x00010001` (bit16 LOCKED) | `0x00010001` (identical) |
| PLL15 mode `0x0338` | *not read* | `0x0` (unused/unfitted) |

**Key observations:**
- PLL2 L/M/N/config/TEST_CTL are **identical** pre and post -- SBL programs them,
  UEFI leaves them. The *only* PLL2 difference is enable (mode `0x0` vs `0x7`).
  When I manually enabled PLL2 pre-UEFI it reached the **same** mode `0x7` /
  status `0x1` as the working golden state.
- **bit16 (lock) is 0 in BOTH states**, even while PLL2 actively clocks a lit
  display. So bit16 is not PLL2's readiness bit (bit0 is). PLL8's bit16 *does*
  set -- lock-detect works, PLL2 just doesn't use it.
- Working display: `mdp_src` enabled, bank 1, source = **PLL2**, at a rate set by
  `md1=0x1fb` / `ns` divider (PLL2 800 MHz / N; exact rate TBD).
- So the kernel boot-20 hang on a PLL2 rate is NOT "no lock" -- PLL2 reaches the
  right register state. Leading theory: cold PLL2 isn't *settled* when the
  dyn-RCG switches `mdp_src` onto it (`clk_pll_enable` blind-waits 50 us, can't
  poll bit16), so MDP sees a not-yet-stable clock -> AHB readl stalls. PXO
  (boot-21) and warm-PLL2 (golden) both dodge this. NB **PLL8 was never booted**
  (`3e69030c` untested) -- it was PXO 27 MHz that passed in boot-21.

**Gaps to fill (need the matching state):**
- Read `mdp_src` (`0xc0/c4/c8/d0`) + footswitch (`0x190`) in the **pre-UEFI raw
  fastboot** state and at **kernel entry** -- to see what the RCG/footswitch
  start at before the kernel touches them (the most diagnostic missing rows).
- Decode the exact golden MDP rate (`md1=0x1fb`, `ns=0x003f0001` vs `clk_tbl_mdp`
  PLL2 rows 160/178/200/229/267 MHz).
- Grab the DSI PLL (golden) for the panel phase.
- Caution: the golden `0x1d0` read returned garbage (`0x7b98b3b9...`) coincident
  with a watchdog reboot -- discard it; avoid `0x1d0+`, keep UART bursts short.

## Next Work

1. **Operating clock (SETTLED -- PLL8):** boot-23 confirms `max_clk=128000000`
   (PLL8, commit `3e69030c`) works end-to-end to userspace, and the boot-21
   `0x100`/vblank errors are GONE (they were the too-slow 27 MHz PXO rate). Keep
   PLL8; do NOT chase PLL2 -- its kernel "missing config" is moot (SBL sets L/M/N
   in HW) and the boot-20 PLL2 hang was cold settle-timing, not config. PLL2 only
   matters if gfx3d/csi are wanted later (a settle fix, not a config one). Device
   gotcha for any boot: `fdt_high=0xffffffff; initrd_high=0xffffffff` in U-Boot
   env before `fastboot boot`, or bootm wedges ("ramdisk - allocation error", no
   software reset).
2. **Scanout / DSI / panel:** chase `errors: 00000100` + `vblank time out` --
   likely the Teisko panel/DSI video path isn't scanning out (panel reset GPIO
   58, DSI video mode, Teisko init sequence); vblank needs the DSI link to
   produce frames.
3. **Productize the footswitch:** the proven GFS power-up (collapse -> enable ->
   unclamp) currently lives in the `mdp4_hack_dump_mmcc()` helper in
   `mdp4_kms.c`. Move it into `mmcc_msm8960_mdp_pd_power_on()` (force a real
   cycle; make power_on actually run), drop the no-op reset bracket, and retire
   the helper + diagnostic HACK commits. Note the `Signed-off-by` cleanup
   (AGENTS.md:54) before anything upstreamable.
4. Confirm panel reset GPIO 58 against stock-FFU `DSI_PANEL_RESET` (DSDT
   resource 15) to reach Tier A; translate PCFG timings into the Teisko panel.
