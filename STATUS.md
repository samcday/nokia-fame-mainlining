# Bring-Up Status Details

Detailed implementation state for Nokia Lumia 520 / `fame` mainline bring-up.

| Area | Status | Current State | Next Work |
| --- | --- | --- | --- |
| Workspace | Candidate | Top-level submodules and notes are seeded. | Commit once reviewed; update submodule pointers as active branches are pushed. |
| Live BootMgr inventory | Candidate | `lp-externals` has safe `NOKV` and `NOKT`; known `TYPE=RM-914`, `CTR=059S083`. | Capture fresh `identify` and `gpt dump` outputs into sanitized notes. |
| FFU corpus | Missing | No FFU is present locally. | Download exact LumiaDB FFU to `extracted/ffu/` and inventory metadata. |
| ACPI/PCFG | Missing | Mainline4Lumia extractor is present; `iasl` is not installed. | Extract/decompile DSDT/SSDT from FFU or ESP artifacts. |
| Kernel | Candidate | `linux/` pinned to msm8227-mainline branch with existing Fame DTS; `qcom-msm8227-nokia-fame.dtb` builds with `qcom_defconfig`. | Fix obvious DTS issues; identify minimal boot image path. |
| U-Boot | Missing | Upstream tree present; ARM32 Snapdragon work exists only in Samsung workspace. | Port minimal ARM32 Snapdragon patches only after a practical handoff/debug path is chosen. |
| USB/display debug | Missing | No UART path; USB/display-only assumption. | Prioritize simplefb/BootMgr display or kernel UDC over silent bootloader experiments. |
| Display | Hypothesis | Android4Lumia says Orise-based 800x480; no FFU PCFG extracted yet. | Mine FFU ACPI/PCFG and compare with existing panel support. |
| Touch | Hypothesis | Android4Lumia says Synaptics; Fame DTS has disabled RMI4 node. | Validate address, IRQ, reset, and supplies before enabling. |
| Storage | Candidate | Fame DTS enables SDCC1 eMMC and SDCC3 but marks SDCC3 `non-removable`. | Compare live GPT, FFU GPT, and pmaports external storage clue. |
