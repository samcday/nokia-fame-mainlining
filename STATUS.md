# Bring-Up Status Details

Detailed implementation state for Nokia Lumia 520 / `fame` mainline bring-up.

| Area | Status | Current State | Next Work |
| --- | --- | --- | --- |
| Workspace | Candidate | Top-level submodules and notes are seeded. | Commit once reviewed; update submodule pointers as active branches are pushed. |
| Live BootMgr inventory | Candidate | `lp-externals` has safe `NOKV` and `NOKT`; known `TYPE=RM-914`, `CTR=059S083`. | Capture fresh `identify` and `gpt dump` outputs into sanitized notes. |
| FFU corpus | Missing | No FFU is present locally. | Download exact LumiaDB FFU to `extracted/ffu/` and inventory metadata. |
| ACPI/PCFG | Missing | Mainline4Lumia extractor is present; `iasl` is not installed. | Extract/decompile DSDT/SSDT from FFU or ESP artifacts. |
| Kernel | Candidate | `linux/` now carries minimal MSM8227 GSBI5 UART plus USB1/ULPI PHY nodes, and the Fame DTB builds with `qcom_defconfig`. | Hardware-test USB/PHY behavior through LK-chain U-Boot; keep broader MSM8227 DTS work source-backed. |
| U-Boot | Working | Raw APPSBL U-Boot reaches a UART prompt at `0x88F00000`; LK-chain U-Boot fastboot works at `0x80208000`; current rebuild has working `oem run`/`oem console`, `bootm`/`abootimg`, and U-Boot-to-U-Boot `fastboot boot` chaining via `bootm start; bootm loados; go`. | Use the chainable U-Boot fastboot path for non-persistent hardware probing; decide whether to add MMC/partition read-only support next. |
| USB/display debug | Working | UART output is available; U-Boot ChipIdea/ULPI fastboot responds to host getvar requests. | Exercise U-Boot command access over fastboot, then decide whether to keep LK-chain or add a safer persistent rescue flow. |
| Display | Hypothesis | Android4Lumia says Orise-based 800x480; no FFU PCFG extracted yet. | Mine FFU ACPI/PCFG and compare with existing panel support. |
| Touch | Hypothesis | Android4Lumia says Synaptics; Fame DTS has disabled RMI4 node. | Validate address, IRQ, reset, and supplies before enabling. |
| Storage | Candidate | Fame DTS enables SDCC1 eMMC and SDCC3 but marks SDCC3 `non-removable`. | Compare live GPT, FFU GPT, and pmaports external storage clue. |
