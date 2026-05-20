# Bring-Up Status Details

Detailed implementation state for Nokia Lumia 520 / `fame` mainline bring-up.

| Area | Status | Current State | Next Work |
| --- | --- | --- | --- |
| Workspace | Candidate | Top-level submodules and notes are seeded. | Commit once reviewed; update submodule pointers as active branches are pushed. |
| Live BootMgr inventory | Candidate | `lp-externals` has safe `NOKV` and `NOKT`; known `TYPE=RM-914`, `CTR=059S083`. | Capture fresh `identify` and `gpt dump` outputs into sanitized notes. |
| FFU corpus | Missing | No FFU is present locally. | Download exact LumiaDB FFU to `extracted/ffu/` and inventory metadata. |
| ACPI/PCFG | Missing | Mainline4Lumia extractor is present; `iasl` is not installed. | Extract/decompile DSDT/SSDT from FFU or ESP artifacts. |
| Kernel | Candidate | `linux/` now carries minimal MSM8227 GSBI5 UART nodes and the Fame DTB builds with `qcom_defconfig`. | Hardware-test UART console handoff; keep broader MSM8227 DTS work source-backed. |
| U-Boot | Candidate | First raw `UEFI` smoke candidate at `0x80208000` stopped during SBL3 image load; the rebuilt candidate now uses the MSM8960 APPSBL window at `0x88F00000`. | After explicit approval, dry-run and write the adjusted smoke image to live `UEFI`, then capture UART logs. |
| USB/display debug | Candidate | UART output is available RX-only; display framebuffer facts remain useful fallback. | Use UART for raw U-Boot bring-up, then return to UDC/fastboot once basic ownership is proven. |
| Display | Hypothesis | Android4Lumia says Orise-based 800x480; no FFU PCFG extracted yet. | Mine FFU ACPI/PCFG and compare with existing panel support. |
| Touch | Hypothesis | Android4Lumia says Synaptics; Fame DTS has disabled RMI4 node. | Validate address, IRQ, reset, and supplies before enabling. |
| Storage | Candidate | Fame DTS enables SDCC1 eMMC and SDCC3 but marks SDCC3 `non-removable`. | Compare live GPT, FFU GPT, and pmaports external storage clue. |
