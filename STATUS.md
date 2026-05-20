# Bring-Up Status Details

Detailed implementation state for Nokia Lumia 520 / `fame` mainline bring-up.

| Area | Status | Current State | Next Work |
| --- | --- | --- | --- |
| Workspace | Candidate | Top-level submodules and notes are seeded. | Commit once reviewed; update submodule pointers as active branches are pushed. |
| Live BootMgr inventory | Candidate | `lp-externals` has safe `NOKV` and `NOKT`; known `TYPE=RM-914`, `CTR=059S083`. | Capture fresh `identify` and `gpt dump` outputs into sanitized notes. |
| FFU corpus | Missing | No FFU is present locally. | Download exact LumiaDB FFU to `extracted/ffu/` and inventory metadata. |
| ACPI/PCFG | Missing | Mainline4Lumia extractor is present; `iasl` is not installed. | Extract/decompile DSDT/SSDT from FFU or ESP artifacts. |
| Kernel | Candidate | `linux/` now carries minimal MSM8227 GSBI5 UART plus USB1/ULPI PHY nodes, and the Fame DTB builds with `qcom_defconfig`. | Hardware-test USB/PHY behavior through LK-chain U-Boot; keep broader MSM8227 DTS work source-backed. |
| U-Boot | Working | Raw APPSBL U-Boot reaches a UART prompt at `0x88F00000`; LK-chain U-Boot fastboot works at `0x80208000`; current rebuild has working `oem run`/`oem console`, `bootm`/`abootimg`, U-Boot-to-U-Boot `fastboot boot` chaining, eMMC/GPT probing, and block-backed `fastboot flash` compiled in. | Keep destructive fastboot flash/erase/GPT operations disabled by procedure unless explicitly requested for a specific target. |
| USB/display debug | Working | UART output is available; U-Boot ChipIdea/ULPI fastboot responds to host getvar requests. | Exercise U-Boot command access over fastboot, then decide whether to keep LK-chain or add a safer persistent rescue flow. |
| Display | Hypothesis | Android4Lumia says Orise-based 800x480; no FFU PCFG extracted yet. | Mine FFU ACPI/PCFG and compare with existing panel support. |
| Touch | Hypothesis | Android4Lumia says Synaptics; Fame DTS has disabled RMI4 node. | Validate address, IRQ, reset, and supplies before enabling. |
| Storage | Working | LK-chain U-Boot initializes SDCC1 as `mmc 0`, reports 8-bit MMC 4.5 `008G92` at 7.3 GiB, reads LBA0, and lists the current live GPT. | Compare live GPT details with the FFU stock GPT and fix SDCC3/external-SD modeling separately. |
