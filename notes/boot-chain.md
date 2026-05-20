# Boot Chain

The current unit has been unlocked with `~/src/lp-externals`, but this workspace has not yet validated an ergonomic chainloader path.

## Current Understanding

| Stage | Status | Notes |
| --- | --- | --- |
| Lumia BootMgr USB | Candidate | Exposes `0421:066e` and `NOK*` protocol. |
| FlashApp/PhoneInfoApp | Candidate | `lp-externals` can switch/read inventory safely. |
| EFIESP | Extracted from stock FFU | FAT16 image at stock GPT LBA `131072`, size `67108864`. |
| ARM UEFI payload | Proven | The unlocked UEFI fallback accepts `IMAGE_FILE_MACHINE_THUMB (0x1C2)` EFI applications from `\efi\boot\bootarm.efi`; `ConOut` and GOP BLT work. |
| U-Boot as ARM EFI app | Proven to main loop | Local U-Boot ARM32 EFI-app patches produce a Lumia-loadable THUMB PE/COFF image that reaches the U-Boot main loop. |
| Raw ARM32 U-Boot payload | Proven to prompt | Unsigned short-header APPSBL at `0x88f00000` reaches U-Boot over GSBI5 UART. |
| LK-chain U-Boot fastboot | Prepared, untested | Android boot image packages U-Boot at LK's `0x80208000` kernel load address and auto-runs `fastboot usb 0`. |

## EFIESP Findings

Source: `extracted/partitions/RM-914-059S083/EFIESP-files/`

| Path | Boot-Chain Relevance |
| --- | --- |
| `/efi/boot/bootarm.efi` | Default ARM UEFI boot path. |
| `/efi/Microsoft/Boot/BCD` | Windows boot entries and policy data. |
| `/efi/Microsoft/Boot/Boot.stl` | Secure boot signature list style file. |
| `/Windows/System32/Boot/mobilestartup.efi` | Main mobile startup EFI app candidate. |
| `/Windows/System32/Boot/mmosloader.efi` | MMOS loader path. |
| `/Windows/System32/Boot/ffuloader.efi` | FFU flashing loader path. |
| `/Windows/System32/Boot/sigcheck.efi` | Signature checking app. |
| `/Nokia/Security/Nokia_Production_PK.bin` | Production platform key blob. |
| `/Nokia/Security/Nokia_RD_PK.bin` | R&D platform key blob. |
| `/Nokia/Security/production_db.bin` | Production allowlist database. |
| `/Nokia/Security/rd_db.bin` | R&D allowlist database. |
| `/Nokia/Security/SecureBootPolicy.p7b` | Production secure boot policy. |
| `/Nokia/Security/SecureBootPolicy_test.p7b` | Test secure boot policy. |

## U-Boot Assessment

The practical U-Boot path is not yet `copy u-boot.efi into ESP`. Current U-Boot has ARM EFI support objects, but the U-Boot-as-EFI-application Kconfig path is gated to x86.

Reusable work from `/var/home/sam/src/samsung-expressltexx-mainlining/u-boot`:

| Area | Reusable Piece |
| --- | --- |
| ARM32 Snapdragon Kconfig | `CONFIG_ARCH_SNAPDRAGON_ARM32` |
| Timer | MSM8960-style debug timer setup and `CFG_SYS_TIMER_COUNTER` |
| Serial | UARTDM v1.3 and GSBI mode programming |
| Defconfig style | Minimal fixed-address ARM32 payload with caches off |

Because the current phone workflow is USB/display-only, U-Boot fastboot should come after at least one visible/debuggable payload milestone.

## Mainline Kernel Beachhead

Current built artifacts from the initial upstream kernel pass:

| Artifact | Path | Size | SHA-256 |
| --- | --- | --- | --- |
| Kernel image | `out/fame/linux-build/arch/arm/boot/zImage` | `9466240` | `fafffcfbe11635c7cb5888d3da6051d683b0b51ddc79bf3bbd83ff2e55ca001e` |
| Device tree | `out/fame/linux-build/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dtb` | `1972` | `27af4989525682b9324aa4f47abf5d18cb4941ed772be9258134e5ff23a0379d` |

The current `qcom_defconfig` build enables `CONFIG_DRM_SIMPLEDRM`, `CONFIG_ARM_APPENDED_DTB`, `CONFIG_OF_FLATTREE`, and `CONFIG_BLK_DEV_INITRD`. It does not enable `CONFIG_EFI`, so these artifacts are kernel payload inputs, not a proven Lumia UEFI executable by themselves.

Validation commands completed for this beachhead:

```sh
make O="/var/home/sam/src/nokia-fame-mainlining/out/fame/linux-build" ARCH=arm CROSS_COMPILE=arm-none-eabi- qcom_defconfig
make O="/var/home/sam/src/nokia-fame-mainlining/out/fame/linux-build" ARCH=arm CROSS_COMPILE=arm-none-eabi- W=1 qcom/qcom-msm8227-nokia-fame.dtb
make O="/var/home/sam/src/nokia-fame-mainlining/out/fame/linux-build" ARCH=arm CROSS_COMPILE=arm-none-eabi- CHECK_DTBS=y qcom/qcom-msm8227-nokia-fame.dtb
make O="/var/home/sam/src/nokia-fame-mainlining/out/fame/linux-build" ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) zImage qcom/qcom-msm8227-nokia-fame.dtb
```

First live-test boundary:

1. Read-only BootMgr inventory commands remain safe before boot testing: `stay-awake`, `identify`, and `gpt dump`.
2. Do not write GPT, EFIESP, boot entries, or firmware partitions just to test this kernel without explicit approval in that turn.
3. If an already-proven chainloader is available, pass the `zImage` and DTB according to that chainloader's ABI; use the simpledrm framebuffer handoff as the first visible success criterion.
4. Expected first useful display signal is Linux taking over the FFU-derived UEFI framebuffer at `0x80400000`, `480x800`, stride `1920`, format `a8r8g8b8`.

## ESP/UEFI Investigation Plan

1. Decode BCD enough to identify the active Windows Phone boot path and any test-signing/debug policy entries.
2. Check whether the unlocked UEFI environment loads unsigned/test-signed EFI binaries from ESP.
3. Build a minimal ARM UEFI hello-world payload before attempting U-Boot.
4. Only after payload handoff is proven, decide whether to port U-Boot ARM EFI app support or use a raw handoff stub.

## Minimal ARM UEFI EFIESP Test

Test image written to live `EFIESP` on 2026-05-19 after a successful `--dry-run` preflight:

| Artifact | Path | Size | SHA-256 |
| --- | --- | --- | --- |
| Replacement EFIESP | `out/fame/uefi-test/EFIESP-minimal-arm-uefi.img` | `67108864` | `092ef52393b07b917fab321cc7e20b6cfc11dae37acbf77264b7747a163d340d` |

Live preflight facts from `~/src/lp-externals flash raw-write-partition --dry-run EFIESP ...`:

| Fact | Value |
| --- | --- |
| Platform secure boot | `false` |
| Secure FFU efuse | `false` |
| UEFI secure boot | `false` |
| EFIESP index | `21` |
| EFIESP sectors | `131072..=262143` |
| EFIESP size | `131072` sectors / `67108864` bytes |
| FlashApp chunk size | `2359296` bytes |

Write command used after explicit confirmation:

```sh
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --confirm-raw-write EFIESP /var/home/sam/src/nokia-fame-mainlining/out/fame/uefi-test/EFIESP-minimal-arm-uefi.img
```

The write completed in 29 chunks and was followed by `cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=false reset`. The phone reached the firmware error screen: `ERROR: Unable to find a bootable option. Press any key to shut down.` This means UEFI was alive but did not treat the replacement `bootarm.efi` as a valid fallback boot option.

The first minimal payload was `IMAGE_FILE_MACHINE_ARMNT (0x1C4)`, while stock `\efi\boot\bootarm.efi` is `IMAGE_FILE_MACHINE_THUMB (0x1C2)`. A second test payload was built from the same Thumb code with only the PE Machine field patched to `0x1C2`.

| Artifact | Path | Size | SHA-256 |
| --- | --- | --- | --- |
| `0x1C2` EFI payload | `minimal-arm-uefi/build/minimal-arm-uefi.efi` | `2560` | `f3188a0336278efa754289599c107e4ce654211fd96b9b435d87e2f096d4824f` |
| `0x1C2` EFIESP | `out/fame/uefi-test/EFIESP-minimal-arm-uefi-thumb.img` | `67108864` | `83feeb3fa1a44126c49be4b38c0e999f692870663a6a367446837b9c1e307d3c` |

The second image passed the same guarded `--dry-run` preflight for live `EFIESP` and was written with:

```sh
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --confirm-raw-write EFIESP /var/home/sam/src/nokia-fame-mainlining/out/fame/uefi-test/EFIESP-minimal-arm-uefi-thumb.img
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=false reset
```

The `0x1C2` write completed in 29 chunks. The next result to record is the physical display behavior after reset.

## Direct Linux EFI-Stub EFIESP Test

Built a direct ARM Linux EFI-stub smoke image from the current Fame kernel tree without changing `qcom_defconfig`. The out-of-tree build config enabled EFI and forced a test-only built-in command line:

```text
CONFIG_EFI=y
CONFIG_EFI_STUB=y
CONFIG_EFI_ARMSTUB_DTB_LOADER=y
CONFIG_CMDLINE_FORCE=y
CONFIG_CMDLINE="dtb=/qcom-msm8227-nokia-fame.dtb console=tty0 loglevel=8 ignore_loglevel efi=debug,novamap,noruntime panic=0"
```

The resulting `zImage` reports as a PE/COFF EFI application with `IMAGE_FILE_MACHINE_THUMB (0x1C2)` and `IMAGE_SUBSYSTEM_EFI_APPLICATION`, matching the Lumia fallback loader's accepted machine type.

| Artifact | Path | Size | SHA-256 |
| --- | --- | --- | --- |
| EFI-stub `zImage` | `out/fame/linux-efi-build/arch/arm/boot/zImage` | `9527808` | `32d6cc6ee52572f326e787c943dee60d707095a1d519427a6aca2c8d5d2de1b4` |
| Fame DTB | `out/fame/linux-efi-build/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dtb` | `1972` | `27af4989525682b9324aa4f47abf5d18cb4941ed772be9258134e5ff23a0379d` |
| Linux EFI EFIESP | `out/fame/uefi-test/EFIESP-linux-efi-smoke.img` | `67108864` | `64d5c003a31b72a1bd37258f3c7e1c069939e4fa4bb6338d10cbf7fcd4f41e80` |

EFIESP layout for the smoke test:

| ESP Path | Source |
| --- | --- |
| `/efi/boot/bootarm.efi` | `out/fame/linux-efi-build/arch/arm/boot/zImage` |
| `/qcom-msm8227-nokia-fame.dtb` | `out/fame/linux-efi-build/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dtb` |

The image had `48417792` bytes free after packaging.

Write command used after a successful guarded dry-run:

```sh
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --confirm-raw-write EFIESP /var/home/sam/src/nokia-fame-mainlining/out/fame/uefi-test/EFIESP-linux-efi-smoke.img
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=false reset
```

The write completed in 29 chunks. After reset, USB re-enumerated as responsive `0421:066e` BootManager (`NOKV` app type 1, BootManager 1.16). Physical display behavior is still the key result to record.

## Minimal ARM UEFI GOP Probe

The minimal ARM UEFI payload was updated to query `EFI_GRAPHICS_OUTPUT_PROTOCOL`. It paints the GOP framebuffer when available and falls back to the FFU-derived hardcoded framebuffer at `0x80400000` otherwise.

Display result encoding:

| Pattern | Meaning |
| --- | --- |
| Green border and white marker block | GOP was located and the payload is painting the GOP framebuffer. |
| Red border | GOP was missing or unusable; payload fell back to the hardcoded framebuffer. |

Test artifacts:

| Artifact | Path | Size | SHA-256 |
| --- | --- | --- | --- |
| GOP-probe EFI payload | `minimal-arm-uefi/build/minimal-arm-uefi.efi` | `4096` | `75849f3d415729f077a7ad75d59580b573d3058cef9e52494e66cf6e05a3cbf5` |
| GOP-probe EFIESP | `out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop.img` | `67108864` | `f90360914ef0e11ebc2e5440fe1f4a8e4f20e6fede91d048ffe37a3de4420c05` |

Write command used after a successful guarded dry-run:

```sh
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --confirm-raw-write EFIESP /var/home/sam/src/nokia-fame-mainlining/out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop.img
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=false reset
```

The write completed in 29 chunks. After reset, USB re-enumerated as `0421:066e` BootManager. Physical display behavior is still the key result to record.

## Opaque GOP Watchdog Test

The GOP probe was revised to write static opaque pixels and to leave the UEFI watchdog unchanged. This test removes the intentional moving diagonal XOR pattern from the first GOP probe and sets the reserved/alpha byte to opaque for RGB/BGR GOP formats.

Display result encoding:

| Pattern | Meaning |
| --- | --- |
| Green border and white marker block | GOP was located and the payload is painting the GOP framebuffer. |
| Red border | GOP was missing or unusable; payload fell back to the hardcoded framebuffer. |
| Static vertical color bars with grid | Expected normal pattern; any remaining diagonal skew is likely real stride/pixel-layout behavior, not an intentional test animation. |

Test artifacts:

| Artifact | Path | Size | SHA-256 |
| --- | --- | --- | --- |
| Opaque GOP EFI payload | `minimal-arm-uefi/build/minimal-arm-uefi.efi` | `4096` | `bbbad06b571706b94aed8d89ac579a87e80217ef53d8b6397b29ae55cbbfd2a8` |
| Opaque GOP EFIESP | `out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-opaque-wdog.img` | `67108864` | `d1c49be3b348e72c769d908734aa08b1dacecf9ecdf39d1ba709f3ea05173458` |

Write command used after a successful guarded dry-run:

```sh
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --confirm-raw-write EFIESP /var/home/sam/src/nokia-fame-mainlining/out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-opaque-wdog.img
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=false reset
```

The write completed in 29 chunks. After reset, USB re-enumerated as `0421:066e` BootManager.

Physical observation from this run: the pixels still were not opaque, the device did not appear to reset or watchdog-bite, and there was faintly legible text near the top of the display. That suggests the visible corruption may be the payload's direct framebuffer writes interacting with firmware console output or display composition rather than a simple alpha-byte issue.

## GOP Text-Only Console Test

The GOP probe was revised again to remove the direct hardcoded framebuffer fallback entirely and to disable all GOP framebuffer painting by default with `static const bool GOP_PAINT_ENABLED = false`. The payload still queries GOP and prints mode/base details via UEFI `ConOut`, then stalls in a loop without direct framebuffer writes.

Expected display result: no color-bar/framebuffer pattern from the payload. If the faint top text was firmware console output, it should be easier to read in this build.

Test artifacts:

| Artifact | Path | Size | SHA-256 |
| --- | --- | --- | --- |
| Text-only GOP EFI payload | `minimal-arm-uefi/build/minimal-arm-uefi.efi` | `3072` | `76646ceb5b02b324ff6dbf9ed3cfde6112840efbe24a1455b252ed917ed310e5` |
| Text-only GOP EFIESP | `out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-text-only.img` | `67108864` | `28da8104aae8a67fa7632d19f5bc519b2debb0ca9758dc32d23f3c884fd7aabd` |

Write command used after switching to FlashApp and passing a guarded dry-run:

```sh
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --confirm-raw-write EFIESP /var/home/sam/src/nokia-fame-mainlining/out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-text-only.img
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=false reset
```

The write completed in 29 chunks. After reset, `lsusb` no longer showed the Nokia BootMgr device, which is consistent with the EFI application running and stalling instead of returning to BootMgr.

Physical observation from this run: UEFI `ConOut` works well. The GOP line reported `480x800` with stride `0x320`, i.e. `800` pixels per scanline. That stride is larger than the visible width and should be safe for a row-major GOP painter, but it is also a useful clue that the backing allocation is not tightly packed to the visible width.

## GOP Decimal Delayed-Paint Test

The GOP probe was revised to print decimal diagnostics instead of padded hex, keep the hardcoded framebuffer fallback removed, and delay for three seconds after `ConOut` before starting GOP-only framebuffer painting. `GOP_PAINT_ENABLED` is set to `true` for this test build.

Expected display sequence:

1. Firmware console text appears first.
2. The GOP mode line should read like `GOP mode 480x800 stride 800 format ...`.
3. `GOP paint delay: 3s` appears.
4. After roughly three seconds, the static GOP test pattern is drawn.

Prepared artifacts, not written to the device by the assistant:

| Artifact | Path | Size | SHA-256 |
| --- | --- | --- | --- |
| Decimal delayed-paint GOP EFI payload | `minimal-arm-uefi/build/minimal-arm-uefi.efi` | `4096` | `b76fba874bcd4e4ee7450fcc3dbf6564578bf312c49be67af6f6a24a304693bd` |
| Decimal delayed-paint GOP EFIESP | `out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-decimal-delay-paint.img` | `67108864` | `fa10c61df18ff3da4281cccbf694cd297b412c85dd2a16a79d0dbd0ccd41705e` |

Suggested guarded write sequence:

```sh
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true switch flash
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --dry-run EFIESP /var/home/sam/src/nokia-fame-mainlining/out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-decimal-delay-paint.img
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --confirm-raw-write EFIESP /var/home/sam/src/nokia-fame-mainlining/out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-decimal-delay-paint.img
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=false reset
```

Physical observation from this run: decimal `ConOut` confirmed `GOP mode 480x800 stride 800 format 1`. GOP format `1` is UEFI `PixelBlueGreenRedReserved8BitPerColor`. The direct framebuffer pattern still looked washed/corrupt after the three-second delay, so the next diagnostic avoids direct framebuffer memory writes entirely.

## GOP BLT Fill Test

The GOP probe was revised to draw the static test pattern with `EFI_GRAPHICS_OUTPUT_PROTOCOL.Blt(EfiBltVideoFill)` rectangles instead of direct framebuffer stores. The hardcoded framebuffer fallback remains removed. The payload still prints decimal GOP diagnostics, waits three seconds, then asks firmware GOP to fill visible rectangles.

Expected display sequence:

1. Firmware console text appears first.
2. The GOP mode line should read `GOP mode 480x800 stride 800 format 1` on this unit.
3. `GOP BLT delay: 3s` appears.
4. After roughly three seconds, the static GOP BLT test pattern is drawn.

Prepared artifacts, not written to the device by the assistant:

| Artifact | Path | Size | SHA-256 |
| --- | --- | --- | --- |
| GOP BLT EFI payload | `minimal-arm-uefi/build/minimal-arm-uefi.efi` | `4608` | `89fc2c399d1e495e1a9ced796b34dceccd76b5ee959641c4e7463dcb426e2b45` |
| GOP BLT EFIESP | `out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-blt-fill.img` | `67108864` | `e63d40b0690bae5027346fc3bfad02b5b30888f752bbff86c1503b8ff674da7f` |

Suggested guarded write sequence:

```sh
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true switch flash
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --dry-run EFIESP /var/home/sam/src/nokia-fame-mainlining/out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-blt-fill.img
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --confirm-raw-write EFIESP /var/home/sam/src/nokia-fame-mainlining/out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-blt-fill.img
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=false reset
```

Physical observation from this run: the BLT-filled pattern rendered correctly, including the small white marker square near the top left. This confirms the firmware GOP implementation and panel path can render cleanly when using GOP services. The earlier corruption is specific to direct framebuffer stores.

## GOP BLT Then Cache-Clean Direct Test

The GOP probe was revised to keep the known-good BLT pattern as a baseline, then try direct framebuffer stores again with explicit ARMv7 data-cache clean by MVA over the touched GOP framebuffer range. The direct pattern is intentionally different from the BLT pattern: BLT draws vertical bars with a green border and top-left white marker; direct stores draw horizontal bars with a red border and bottom-right white marker.

Expected display sequence:

1. Firmware console text appears first.
2. The GOP mode line should read `GOP mode 480x800 stride 800 format 1` on this unit.
3. `GOP BLT delay: 3s` and `GOP direct delay: 3s after BLT` appear.
4. After roughly three seconds, the known-good BLT pattern appears.
5. After roughly three more seconds, the cache-cleaned direct-write pattern should replace it if direct stores are usable.

Prepared artifacts, not written to the device by the assistant:

| Artifact | Path | Size | SHA-256 |
| --- | --- | --- | --- |
| BLT/direct-clean EFI payload | `minimal-arm-uefi/build/minimal-arm-uefi.efi` | `5632` | `1e547160c2f1f78ddbab25f6859e067b5c1c4cb42c691b371a272adf4907ca52` |
| BLT/direct-clean EFIESP | `out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-blt-direct-clean.img` | `67108864` | `a972bd4930a7db32b4fb63a5ff0107b4138019cf3ba7539f326c0c9df12d15a0` |

Suggested guarded write sequence:

```sh
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true switch flash
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --dry-run EFIESP /var/home/sam/src/nokia-fame-mainlining/out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-blt-direct-clean.img
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --confirm-raw-write EFIESP /var/home/sam/src/nokia-fame-mainlining/out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-blt-direct-clean.img
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=false reset
```

Physical observation from this run: the display stayed on the BLT pattern and never updated to the direct framebuffer pattern. That leaves two main possibilities: execution did not reach the direct-write phase after BLT, or direct stores/cache-clean still did not affect the displayed scanout.

## GOP Post-BLT ConOut Then Direct Test

The GOP probe was revised to insert an observable `ConOut` checkpoint between the BLT pattern and the direct framebuffer stores. The payload prints/draws the same initial diagnostics and known-good BLT baseline, waits three seconds, writes `Post-BLT ConOut: OK; direct in 3s`, waits another three seconds, then attempts the cache-cleaned direct framebuffer pattern.

Expected display sequence:

1. Firmware console text appears first.
2. The GOP mode line should read `GOP mode 480x800 stride 800 format 1` on this unit.
3. After roughly three seconds, the known-good BLT pattern appears.
4. After roughly three more seconds, `Post-BLT ConOut: OK; direct in 3s` should appear if execution is still progressing after BLT.
5. After roughly three more seconds, the cache-cleaned direct-write pattern should replace the BLT pattern if direct stores are usable.

Prepared artifacts, not written to the device by the assistant:

| Artifact | Path | Size | SHA-256 |
| --- | --- | --- | --- |
| BLT/post-ConOut/direct EFI payload | `minimal-arm-uefi/build/minimal-arm-uefi.efi` | `5632` | `fd044c327774427182bc8daa0e14ea5494e457aa2b7b187686530565358abf5f` |
| BLT/post-ConOut/direct EFIESP | `out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-blt-conout-direct-clean.img` | `67108864` | `18e1f7850b34204e27ddb3fa8f99a6849e7fbedbbde8bb9c2a44d0b147fcf8a9` |

Suggested guarded write sequence:

```sh
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true switch flash
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --dry-run EFIESP /var/home/sam/src/nokia-fame-mainlining/out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-blt-conout-direct-clean.img
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --confirm-raw-write EFIESP /var/home/sam/src/nokia-fame-mainlining/out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-blt-conout-direct-clean.img
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=false reset
```

Physical observation from this run: the post-BLT `ConOut` checkpoint appeared, so execution continued after the BLT pattern. No visible direct framebuffer update appeared afterward. This means either the direct-store/cache-clean sequence did not complete, or it completed but did not affect the active scanout.

## GOP Direct Checkpoint Test

The GOP probe was narrowed to identify where the direct path stops. It keeps the known-good BLT baseline and post-BLT `ConOut` checkpoint, then writes only a 64x64 bottom-right direct framebuffer marker. It prints checkpoints before direct stores, after direct stores with readback, before cache clean, and after cache clean with readback.

Expected display sequence:

1. Firmware console text appears first.
2. After roughly three seconds, the known-good BLT pattern appears.
3. After roughly three more seconds, `Post-BLT ConOut: OK; direct in 3s` appears.
4. After roughly three more seconds, `Direct store: start` should appear.
5. If direct stores complete, `Direct store: done read <value>` should appear.
6. If cache clean starts/completes, `Direct clean: start` and `Direct clean: done read <value>` should appear.
7. If direct scanout works, a small red/white marker should appear near the bottom right over the BLT pattern.

Prepared artifacts, not written to the device by the assistant:

| Artifact | Path | Size | SHA-256 |
| --- | --- | --- | --- |
| Direct-checkpoint EFI payload | `minimal-arm-uefi/build/minimal-arm-uefi.efi` | `5632` | `9aaffd9a4b891fc539140b7ec0b16e5b756ae53049849dcace2ac4400d4fd31e` |
| Direct-checkpoint EFIESP | `out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-direct-checkpoints.img` | `67108864` | `684abda8cc68074b7f71a31de0a85eda1524d6247efa18a497c11a0d88d27efe` |

Suggested guarded write sequence:

```sh
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true switch flash
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --dry-run EFIESP /var/home/sam/src/nokia-fame-mainlining/out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-direct-checkpoints.img
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --confirm-raw-write EFIESP /var/home/sam/src/nokia-fame-mainlining/out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-direct-checkpoints.img
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=false reset
```

Physical observation from this run: direct-store and cache-clean checkpoints appeared and both readbacks printed `0`, with no visible direct framebuffer marker. The readback value was ambiguous because the helper used `0` for both skipped markers and actual reads. The user also confirmed GOP `FrameBufferBase` is `2151677952` (`0x80400000`) and `FrameBufferSize` is `1536000`, exactly `480 * 800 * 4`. That contradicts the GOP-reported `PixelsPerScanLine = 800` for direct full-height access: `800 * 800 * 4` would need `2560000` bytes.

## GOP Dual-Stride Direct Marker Test

The GOP probe was revised to test the stride contradiction directly. It keeps the known-good BLT baseline and post-BLT `ConOut` checkpoint, then writes two 64x64 direct framebuffer markers with printed byte offsets and readbacks:

| Marker | Addressing | Intended Position | Fill |
| --- | --- | --- | --- |
| GOP-stride marker | `PixelsPerScanLine = 800` | Upper right, safe within the tight reported size | Blue with white center |
| Tight-stride marker | `width = 480` | Bottom right, safe within `1536000` bytes | Red with white center |

Expected display sequence:

1. Firmware console text appears first.
2. After roughly three seconds, the known-good BLT pattern appears.
3. After roughly three more seconds, `Post-BLT ConOut: OK; direct in 3s` appears.
4. The direct phase prints each marker's `offset`, `end`, `read`, and `clean read` values.
5. If direct scanout uses GOP stride, the blue/white marker may appear near the upper right.
6. If direct scanout uses tight stride, the red/white marker should appear near the bottom right.

Prepared artifacts, not written to the device by the assistant:

| Artifact | Path | Size | SHA-256 |
| --- | --- | --- | --- |
| Dual-stride direct EFI payload | `minimal-arm-uefi/build/minimal-arm-uefi.efi` | `6144` | `39d22a34500fc74a66cf8c2787c8ee6c89b933ddfe21cf9ee4ba49fe657f3b92` |
| Dual-stride direct EFIESP | `out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-dual-stride-direct.img` | `67108864` | `774d03108076036c48eea2b62a45fe78ecba1e2f58729800176d23a275bc9c84` |

Suggested guarded write sequence:

```sh
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true switch flash
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --dry-run EFIESP /var/home/sam/src/nokia-fame-mainlining/out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-dual-stride-direct.img
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --confirm-raw-write EFIESP /var/home/sam/src/nokia-fame-mainlining/out/fame/uefi-test/EFIESP-minimal-arm-uefi-gop-dual-stride-direct.img
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=false reset
```

Physical observation from this run: the expected red/white tight-stride marker appeared at the bottom right. This solidifies the display model for direct scanout on this unit: although GOP reports `PixelsPerScanLine = 800`, the visible direct framebuffer is the tight `480 * 800 * 4 = 1536000` byte allocation at `0x80400000`, so direct writers must use a `480` pixel / `1920` byte stride. GOP BLT remains the cleanest firmware display path, but tight-stride direct stores are also visible.

## U-Boot EFI App Debrief

The first U-Boot EFI-app fastboot/UMS candidate uses the proven ARM32 EFI app path and an embedded Fame/MSM8960-style `qcom,ci-hdrc` USB node at `0x12500000`. It enables EFI GOP video with a framebuffer-size stride clamp, Qualcomm ULPI PHY `qcom,init-seq`, ChipIdea gadget fastboot, and a fallback boot menu.

First live result from the initial `vidconsole` environment: the device rebooted immediately after printing `EFI GOP stride exceeds framebuffer size, using visible width`. That warning is emitted before U-Boot's video uclass clears the framebuffer for `vidconsole`, so the next candidate leaves output on EFI `serial`/`ConOut` only. `CONFIG_VIDEO_EFI` remains built in for later manual probing, but automatic boot no longer asks for `vidconsole`.

Second live result from the serial-only console environment: the device appeared to hang after printing `ofnode_read_prop: qcom,init-seq:`. That line is a debug prefix emitted by U-Boot's OF property reader and does not prove the property read hung; the likely next operation is the Qualcomm ULPI PHY setup path. The host also observed a new high-speed USB enumeration attempt with `device descriptor read/64, error -71`, which is a useful sign that the ChipIdea gadget path may have asserted pull-up but failed before a valid descriptor transfer.

This avenue is parked. Current U-Boot is running as `u-boot-app.efi`, not as a takeover payload. In this mode U-Boot does not call `ExitBootServices()`; it keeps UEFI Boot Services alive and even uses them for EFI `serial`/`ConOut` and delays. That makes direct hardware ownership fragile: U-Boot pokes USB and framebuffer hardware while firmware services may still own state, timers, and protocols. A later `bootz` from this mode would jump to Linux without a clean UEFI `ExitBootServices()` handoff, so it is not a sound final chainloader path.

Future work should prefer one of these paths instead:

1. Debug direct Linux EFI-stub boot, where Linux itself is the EFI application and can call `ExitBootServices()` correctly.
2. Build a small ARM EFI Linux loader that stays within UEFI rules and leaves `ExitBootServices()` to Linux.
3. Port the U-Boot EFI payload/stub model to ARM32 if U-Boot must own hardware before Linux. This is conceptually the right U-Boot takeover model, but upstream's payload support is currently x86-centric.

Prepared artifacts, not written to the device by the assistant:

| Artifact | Path | Size | SHA-256 |
| --- | --- | --- | --- |
| U-Boot EFI app, serial-only console | `out/fame/uefi-test/u-boot-app-fame-udc-fastboot-serial-only.efi` | `483840` | `ad479aac9d687fd1bc0e9372c67389263ad38c754a3c048d7c0a617ed5669d11` |
| U-Boot fastboot EFIESP, serial-only console | `out/fame/uefi-test/EFIESP-u-boot-fame-udc-fastboot-serial-only.img` | `67108864` | `c128626e57f3271ffebdc93b66e2ae499d02d007fd0333af85cec6b688f3d651` |

The shorter artifact names `out/fame/uefi-test/u-boot-app-fame-udc-fastboot.efi` and `out/fame/uefi-test/EFIESP-u-boot-fame-udc-fastboot.img` currently contain the same serial-only build.

The EFI app header checks as `IMAGE_FILE_MACHINE_THUMB (0x1C2)`, PE32, `IMAGE_SUBSYSTEM_EFI_APPLICATION`, entrypoint `0x1001`, `ImageBase = 0x400000`, and a base-relocation directory at RVA `0x76000`.

EFIESP layout for the candidate:

| ESP Path | Source |
| --- | --- |
| `/efi/boot/bootarm.efi` | `out/fame/u-boot-efi-arm-app32/u-boot-app.efi` |
| `/qcom-msm8227-nokia-fame.dtb` | `out/fame/linux-build/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dtb` |

Generated U-Boot environment highlights:

```text
stdin=serial
stdout=serial
stderr=serial
bootcmd=run fastboot; run menucmd
fastboot=fastboot -l $fastboot_addr_r -s $fastboot_size usb 0
fastboot_bootcmd=run load_fdt && bootz $fastboot_addr_r - $fdt_addr_r
load_fdt=fatload efi 0:EFIESP $fdt_addr_r /$fdtfile || fatload efi 0:21 $fdt_addr_r /$fdtfile
ums_efiesp=echo Exporting EFIESP over USB mass storage; ums 0 efi 0:EFIESP || ums 0 efi 0:21
```

Archived guarded write sequence, only after explicit approval to write live EFIESP:

```sh
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true switch flash
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --dry-run EFIESP /var/home/sam/src/nokia-fame-mainlining/out/fame/uefi-test/EFIESP-u-boot-fame-udc-fastboot-serial-only.img
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --confirm-raw-write EFIESP /var/home/sam/src/nokia-fame-mainlining/out/fame/uefi-test/EFIESP-u-boot-fame-udc-fastboot-serial-only.img
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=false reset
```

Do not spend further bring-up time on this exact `u-boot-app.efi` fastboot path unless the goal is explicitly diagnostic. If it is revisited, reduce OF/debug verbosity, add explicit progress prints around `ehci_usb_probe()`, `generic_setup_phy()`, ULPI writes, `usb_setup_ehci_gadget()`, and descriptor handling, and consider a no-U-Boot-PHY-touch candidate first.

## Raw U-Boot UART Smoke Candidate

With device-to-host UART now available, the first non-EFI U-Boot candidate is intentionally UART-only. The build path uses `linux/` as the canonical DT source and feeds the resulting DTB to U-Boot with `EXT_DTB`.

Source/layout breadcrumbs:

| Fact | Source |
| --- | --- |
| Stock `UEFI` partition is 5000 sectors / `2560000` bytes | `notes/partitions.md:38`, `notes/partitions.md:68` |
| Lumia UEFI images use a short Qualcomm partition header and `image_src=0` means image bytes start after the `0x28`-byte header | `prior-art/WPinternals/WPinternals/Models/QualcommPartition.cs:99-131`, `prior-art/WPinternals/WPinternals/Models/UEFI.cs:52-56` |
| MSM8960-family LK APPSBL memory base is `0x88F00000`, size `0x00100000`; `0x80200000` is the downstream kernel base, not the appsbl base | `prior-art/mainline4lumia-lk2nd/target/msm8960/rules.mk:7-10` |
| U-Boot UART smoke `TEXT_BASE` / MBN destination is now `0x88F00000` | `u-boot/configs/nokia_fame_defconfig`, `build-u-boot-uefi-smoke.sh` `TEXT_BASE` default |
| GSBI5 UARTDM base and interrupt are source-backed before DTS enablement | `notes/hardware-inventory.md` debug UART mapping row |

First live raw-`UEFI` test result, reported by the user after flashing the original `0x80208000` candidate:

```text
B -    553880 - sbl3_hw_init, Start
D -         0 - sbl3_hw_init, Delta
B -    560376 - boot_flash_init, Start
D -     22356 - boot_flash_init, Delta
B -    588558 - boot_smem_init, Start
D -       732 - boot_smem_init, Delta
B -    595421 - sbl3_hw_init_secondary, Start
B -    733647 - pm_pwron_regulate_ calls...
B -    736392 - pm_pwron_regulate_ calls done.
D -    141001 - sbl3_hw_init_secondary, Delta
B -    745084 - VIBRA

B -    878461 - Image Load, Start
```

Interpretation: no U-Boot output was observed, and the SBL3 log stopped at `Image Load, Start`. A later Android4Lumia LK control image was accepted by SBL3 with the same unsigned short-header APPSBL style, so this first U-Boot failure is now most likely due to its incorrect `0x80208000` destination rather than a signature/certificate requirement. The next U-Boot candidate moves U-Boot into the MSM8960 APPSBL window at `0x88F00000`.

Follow-up recovery observation: after this failed boot the phone enumerated as Qualcomm `05c6:9006` / `QHSUSB_DLOAD` mass storage, exposing raw eMMC to Linux. The live `UEFI` partition was `/dev/sda7` and `BACKUP_UEFI` was `/dev/sda14`; both were 5000 sectors. Direct reads showed `/dev/sda7` still matched the failed first candidate hash `5299aacfa27de4b14af9ce65f15f88c23dbffcd2c71caa00a613b2a8973036d7`, while `/dev/sda14` hashed as `7a3f72b0923da7844fe7d21832df0b9237e768c62bb2ea4a85ef69328ab77b79`. Stock `UEFI` was restored by copying `BACKUP_UEFI` over `UEFI`; a direct readback of `/dev/sda7` then matched `/dev/sda14` at `7a3f72b0923da7844fe7d21832df0b9237e768c62bb2ea4a85ef69328ab77b79`.

Build helper:

```sh
./build-u-boot-uefi-smoke.sh
```

This helper builds `make -C linux ... dtbs`, builds U-Boot `nokia_fame_defconfig` with `EXT_DTB=<linux-built Fame DTB>`, emits a Qualcomm appsbl-style MBN header, and pads the result to exactly the stock `UEFI` partition size. It does not flash the device.

Prepared artifacts from the adjusted APPSBL-addressed build, not written to the device by the assistant:

| Artifact | Path | Size | SHA-256 |
| --- | --- | --- | --- |
| Fame DTB | `out/fame/linux-build/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dtb` | `2625` | `cd446d1bc898d32fe33a6f7c3d8627bb5c54afc4db23f4677208612026dad664` |
| Raw U-Boot with external DTB | `out/fame/u-boot-fame-smoke/u-boot-dtb.bin` | `179177` | `72366c52091877e53feae80963703d8248b4d69254a5664463aaa9f266ebdfc1` |
| Qualcomm appsbl-style MBN | `out/fame/u-boot-uefi-smoke/u-boot-fame-uart-smoke.mbn` | `179224` | `714972f71de3bdaac632941abeff58d53a175a3d70fd0291bd05e126e0b862e4` |
| Padded `UEFI` candidate | `out/fame/u-boot-uefi-smoke/UEFI-u-boot-fame-uart-smoke.bin` | `2560000` | `7d71fba4e17a672e59af257776b2bb369c177d1b8904ea1b320023ca0cd6780b` |

The MBN packaging pads the `179177`-byte `u-boot-dtb.bin` payload to an 8-byte boundary before calculating the Qualcomm header fields. The copied APPSBL image length is therefore `179184` bytes, matching the bytes after the `0x28`-byte header.

MBN header spot-check from the built candidate:

```text
image_id=0x00000005
flash_partition_version=0x00000003
image_src=0x00000000
image_dest=0x88f00000
image_size=0x0002bbf0
code_size=0x0002bbf0
signature_ptr=0x88f2bbf0
signature_size=0
cert_chain_ptr=0x88f2bbf0
cert_chain_size=0
```

Validation results:

```sh
./build-u-boot-uefi-smoke.sh
bash -n ./build-u-boot-uefi-smoke.sh
arm-none-eabi-readelf -h out/fame/u-boot-fame-smoke/u-boot
make -C linux O=/var/home/sam/src/nokia-fame-mainlining/out/fame/linux-build ARCH=arm CROSS_COMPILE=arm-none-eabi- W=1 qcom/qcom-msm8227-nokia-fame.dtb
```

The build and syntax checks completed successfully, and `readelf` reports U-Boot entry point `0x88f00000`. Targeted `CHECK_DTBS=y qcom/qcom-msm8227-nokia-fame.dtb` did not reach DT validation because the host `dtschema` version check failed first with `ERROR: dtschema minimum version is v2023.9`.

Guarded live-device sequence printed by the helper, only after explicit approval to write live `UEFI`:

```sh
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true switch flash
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --dry-run UEFI /var/home/sam/src/nokia-fame-mainlining/out/fame/u-boot-uefi-smoke/UEFI-u-boot-fame-uart-smoke.bin
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=true flash raw-write-partition --confirm-raw-write UEFI /var/home/sam/src/nokia-fame-mainlining/out/fame/u-boot-uefi-smoke/UEFI-u-boot-fame-uart-smoke.bin
cargo run --manifest-path /var/home/sam/src/lp-externals/Cargo.toml -- --wait=false reset
```

## Android4Lumia LK APPSBL Control

The Android4Lumia LK submodule worktree in `community/android4lumia-lk-msm8227` had all tracked files deleted at the time of this check, so the control build was done from a detached temporary worktree at `out/fame/android4lumia-lk-msm8227-src` without changing the submodule state.

Build command:

```sh
make PROJECT=msm8960 BOOTLOADER_OUT=/var/home/sam/src/nokia-fame-mainlining/out/fame/android4lumia-lk-build clean
make TOOLCHAIN_PREFIX=arm-none-eabi- CC="arm-none-eabi-gcc -fcommon -Wno-error=implicit-function-declaration -Wno-error=int-conversion -Wno-error=incompatible-pointer-types -Wno-error=return-mismatch" BOOTLOADER_OUT=/var/home/sam/src/nokia-fame-mainlining/out/fame/android4lumia-lk-build msm8960 EMMC_BOOT=1
```

The compatibility flags are only for building this old LK tree with Fedora/GCC 15. They do not change source files. The build emits `Image Destination Pointer: 0x88f00000`, `lk.bin`, `EMMCBOOT.MBN`, and `emmc_appsboot.mbn`.

Prepared artifacts from the LK control build, not written to the device by the assistant:

| Artifact | Path | Size | SHA-256 |
| --- | --- | --- | --- |
| LK raw binary | `out/fame/android4lumia-lk-build/build-msm8960/lk.bin` | `452088` | `cc5f046131af696f0eef3e0794d06a4f9d28e396b337884e2d8f0c138a75d12d` |
| LK Qualcomm appsbl-style MBN | `out/fame/android4lumia-lk-build/build-msm8960/EMMCBOOT.MBN` | `452128` | `3b1710d6b26cb47cc616ab761436c56ccd4418c75b8f58fcbdaa58caf7c10fe9` |
| Padded LK `UEFI` candidate | `out/fame/android4lumia-lk-build/UEFI-android4lumia-lk-msm8960.bin` | `2560000` | `f2778f084de34b5802a68c498249ec9e5f18fa5635ddf8eb249bd8e89e58da69` |

Live result reported by the user: the padded LK `UEFI` candidate was accepted by SBL3. The SBL log included `APPSBL Image Loaded`, LK printed `Android Bootloader - UART_DM Initialized!!!`, entered fastboot, and processed `getvar`/`oem lk_log` commands. `fastboot getvar all` reported product `MSM8960`, kernel `lk`, version `0.5`, and `max-download-size` `0x30000000`; the device serial was intentionally not recorded here. This proves stock SBL3 on this unit can load an unsigned short-header APPSBL image at `0x88f00000`.

`lp-externals qcom image-info` for the LK `EMMCBOOT.MBN`:

```text
source format: raw
source bytes: 452128
header type: short
image offset: 0x00000028
header offset: 0x00000008
image address: 0x88f00000
image size: 452088
code size: 452088
signature address: 0x88f6e5f8
signature size: 0
certificates address: 0x88f6e5f8
certificates size: 0
root key hash: 9f27065873d09a099ca52ffa34bb856ee4f5fa4e1ff8fe0a6e4158307d669f46
```

The parsed `root key hash` is not evidence that this MBN carries an APPSBL cert chain: `lp-externals` currently derives that value by scanning the whole image for DER certificates, and this LK build links OpenSSL data. The authoritative MBN fields still show `signature size: 0` and `certificates size: 0`.

Comparison with the current U-Boot smoke MBN:

| Field | LK `EMMCBOOT.MBN` | U-Boot smoke MBN |
| --- | --- | --- |
| Header type | `short` | `short` |
| Image offset | `0x00000028` | `0x00000028` |
| Header offset | `0x00000008` | `0x00000008` |
| Image address | `0x88f00000` | `0x88f00000` |
| Image size | `452088` | `179184` |
| Code size | `452088` | `179184` |
| Signature size | `0` | `0` |
| Certificate chain size | `0` | `0` |

Interpretation: Android4Lumia LK does not reveal a different APPSBL wrapper, and the live test proves one is not needed on this unit. LK has the same unsigned short-header structure as the current U-Boot candidate, just with a larger and naturally aligned code payload. The practical U-Boot cleanup after this result is to keep `TEXT_BASE=0x88f00000` and pad the U-Boot payload before MBN header generation so the zero-size signature/cert pointers are aligned.

No local stock UEFI or FFU image was present under this workspace during this comparison.

## LK-Chain U-Boot Fastboot Candidate

With LK proven as the persistent recovery APPSBL, the next U-Boot test path is `fastboot boot` from LK instead of writing raw APPSBL images. This keeps the known-good LK in `UEFI` and loads U-Boot as a normal Android boot image kernel payload at the downstream kernel address window.

Build helper:

```sh
./build-u-boot-lk-fastboot.sh
```

The helper builds the Linux Fame DTB, builds U-Boot `nokia_fame_lk_fastboot_defconfig` with `EXT_DTB=<linux-built Fame DTB>`, verifies `CONFIG_TEXT_BASE == 0x80208000`, and wraps `u-boot-dtb.bin` in an Android boot image header v0.

Prepared artifacts from the fastboot-flash-capable rebuild:

| Artifact | Path | Size | SHA-256 |
| --- | --- | --- | --- |
| Fame DTB with USB and SDCC1 nodes | `out/fame/linux-build/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dtb` | `4124` | `83b031a23617296a08a2f07fe389a3dc8fcce55a6b6561021986f86c8902d482` |
| LK-chain U-Boot payload with `bootm`/`abootimg`/MMC/fastboot flash | `out/fame/u-boot-fame-lk-fastboot/u-boot-dtb.bin` | `334636` | `954ef386d8de4528f217e8add25fed8edcea63e8c2b982367417b48fa6c7d6c6` |
| Android boot image with `bootm`/`abootimg`/MMC/fastboot flash | `out/fame/u-boot-lk-fastboot/u-boot-fame-lk-fastboot.img` | `339968` | `c0af12e1324aff449954e28547d858a4181fcd7a282d2e28f0cfe8e1b0c9d92c` |

`unpack_bootimg` verification:

```text
boot magic: ANDROID!
kernel_size: 334636
kernel load address: 0x80208000
ramdisk size: 0
kernel tags load address: 0x80200100
page size: 4096
boot image header version: 0
product name: nokia-fame
```

U-Boot config highlights:

```text
CONFIG_TEXT_BASE=0x80208000
CONFIG_BOOTCOMMAND="fastboot usb 0"
CONFIG_FASTBOOT_BUF_ADDR=0x82000000
CONFIG_CMD_BOOTM=y
CONFIG_CMD_BOOTZ=y
CONFIG_CMD_ABOOTIMG=y
CONFIG_CMD_ADTIMG=y
CONFIG_CMD_LSBLK=y
CONFIG_CMD_MMC=y
CONFIG_CMD_PART=y
CONFIG_CMD_READ=y
CONFIG_CMD_FASTBOOT=y
CONFIG_EFI_PARTITION=y
# CONFIG_ANDROID_BOOT_IMAGE_IGNORE_BLOB_ADDR is not set
CONFIG_FASTBOOT_FLASH=y
CONFIG_FASTBOOT_FLASH_BLOCK=y
CONFIG_FASTBOOT_FLASH_BLOCK_INTERFACE_NAME="mmc"
CONFIG_FASTBOOT_FLASH_BLOCK_DEVICE_ID=0
CONFIG_FASTBOOT_GPT_NAME="gpt"
CONFIG_ARM_PL180_MMCI=y
CONFIG_MMC_WRITE=y
# CONFIG_MMC_HW_PARTITIONING is not set
CONFIG_USB_FUNCTION_FASTBOOT=y
CONFIG_CI_UDC=y
CONFIG_USB_EHCI_MSM=y
CONFIG_USB_ULPI_VIEWPORT=y
CONFIG_MSM8916_USB_PHY=y
CONFIG_CONSOLE_RECORD=y
CONFIG_CONSOLE_RECORD_OUT_SIZE=0x100000
CONFIG_FASTBOOT_OEM_RUN=y
CONFIG_FASTBOOT_CMD_OEM_CONSOLE=y
CONFIG_FASTBOOT_BUF_SIZE=0x04000000
```

First live result reported by the user, before adding `oem run`: the LK-chain image booted cleanly, U-Boot's ChipIdea/ULPI gadget enumerated as fastboot, and host `fastboot getvar all` completed. Reported values included `version: 0.4`, `version-bootloader: U-Boot 2026.07-rc2-00022-g90434f09f01e-`, `downloadsize`/`max-download-size: 0x04000000`, `product: nokia-fame`, and `is-userspace: no`.

Live probe of the `oem console` image showed `fastboot oem console` failed with `remote: 'Error reading console'`, likely because the console record overflow flag was set by boot-time output before the host tried to drain it. The chain-capable rebuild resets the console recorder before each `oem run` command, increases `CONFIG_CONSOLE_RECORD_OUT_SIZE` to `0x100000`, reports/clears console overflow instead of permanently failing `oem console`, and treats an empty console as OKAY.

Live result after rebuilding: `fastboot oem run:version` followed by `fastboot oem console` returns the command output, and a second empty `fastboot oem console` returns OKAY. `bootm` and `abootimg` are available over `oem run`.

The first nested `fastboot boot` attempt with plain `bootm 0x82000000` parsed and loaded the Android image, then continued into the Linux boot path and failed with `FDT and ATAGS support not compiled in`. The working chain command is:

```text
bootm start 0x82000000; bootm loados; go 0x80208000
```

This command loads the Android boot-image kernel payload to `CONFIG_TEXT_BASE` and jumps to the fixed-link U-Boot entry instead of invoking Linux `bootm` handoff. The final rebuild installs it as `fastboot_bootcmd` for the Fame-compatible ARM32 Snapdragon path. Live U-Boot-to-U-Boot chaining with the final image re-enumerated fastboot successfully; one host `getvar all` raced the USB disconnect/reconnect with `No such device`, and a retry completed normally.

The first eMMC-capable build exposed SDCC1 as `mmc@12400000: 0`, but `mmc dev 0` timed out with `Card did not respond to voltage select! : -110` because U-Boot had no MSM8960 GCC provider and SDCC1 app clocks were only LK leftovers. A volatile manual SDC1 app-clock setup changed the failure to an EXT_CSD data CRC, proving the card was responding. The remaining data CRC came from using the generic PL18x log2 block-size encoding; Qualcomm's MMCI variant uses the byte block size in bits `[14:4]`, matching `linux/drivers/mmc/host/mmci_qcom_dml.c:183-185` and `community/android4lumia-lk-msm8227/platform/msm_shared/mmc.c:2612-2616`.

Final live eMMC result from the LK-chain image:

```text
mmc@12400000: 0
Device: mmc@12400000
Manufacturer ID: 11
Name: 008G92
Bus Speed: 48000000
Mode: MMC High Speed (52MHz)
Rd Block Len: 512
MMC version 4.5
High Capacity: Yes
Capacity: 7.3 GiB
Bus Width: 8-bit
User Capacity: 7.3 GiB WRREL
Boot Capacity: 4 MiB ENH
RPMB Capacity: 512 KiB ENH
```

`part list mmc 0` reads the current live GPT successfully. The current live disk has the stock FFU partition set plus an extra `HACK` entry at LBA `0x8bb7`; keep this distinct from the stock FFU GPT in `notes/partitions.md`. A direct read-only block test also succeeded: `mmc read 0x82000000 0 1` read one block, the PMBR signature at `0x820001fe` was `55 aa`, and `crc32 0x82000000 0x200` returned `9c6b8c10`.

Fastboot block flash support was then cherry-picked from lore:

```text
ab4f3dbe690 fastboot: block: Add device selection syntax
168a57db0d3 fastboot: Add GPT/MBR partition table flashing helper functions
7cac3c93240 fastboot: block: Add GPT/MBR partition table flashing support
0d5137d18e7 doc: fastboot: Document block device selection syntax
1999914a59b qcom_defconfig: Switch Qualcomm fastboot flash from MMC to block
```

Fame's LK-chain config now enables the block backend for `mmc` device `0`, so partition names target the default eMMC and the lore device-selection syntax can select an explicit block device. `fastboot flash gpt <image>` support is compiled in through the GPT helper path. This was only build-tested and boot-smoke-tested with `fastboot getvar all` plus `mmc info`; no live `fastboot flash`, `fastboot erase`, GPT write, or partitioning command was run.

The `oem run` command takes the U-Boot command after a colon:

```sh
fastboot oem run:version
fastboot oem run:bdinfo
fastboot oem 'run:dm tree'
fastboot oem console
```

Live test command from the working LK fastboot prompt:

```sh
fastboot boot /var/home/sam/src/nokia-fame-mainlining/out/fame/u-boot-lk-fastboot/u-boot-fame-lk-fastboot.img
```

This is not a write. Expected behavior is U-Boot UART output, a one-second autoboot window, then `fastboot usb 0`. If the ChipIdea/ULPI path fails cleanly, U-Boot should return to its UART prompt; if it hangs, reset back into the persistent LK APPSBL and continue from LK fastboot.

## Raw U-Boot APPSBL Result And UART Stage0 Rescue

Live result reported by the user: the aligned U-Boot APPSBL image was accepted by SBL3. The SBL log included `APPSBL Image Loaded`, then U-Boot reached the relocated main loop and prompt over GSBI5 UART. This confirms the raw U-Boot APPSBL path is viable when the MBN destination is `0x88f00000` and the payload size/signature pointers are aligned.

Useful U-Boot facts from the live prompt:

| Fact | Value |
| --- | --- |
| Prompt reached | yes, `=>` |
| Model | `Nokia Lumia 520` |
| Console | `serial@16440000` |
| DRAM bank 0 | `0x80200000..0x88dfffff`, `0x08c00000` bytes |
| DRAM bank 1 | `0x90000000..0x9fffffff`, `0x10000000` bytes |
| Relocated U-Boot | `0x9ffd0000` |
| FDT blob | `0x8ffb0490` |
| Probed DM devices | root, SoC simple-bus, GSBI5 simple-bus, `serial@16440000` |

The current smoke defconfig intentionally omitted most commands. The live command set included memory commands and `go`, but not `loadb`, `loads`, `mmc`, `usb`, `fastboot`, `ums`, or filesystem commands. `reset` failed with `System reset not supported on this platform`. Manual IMEM DLOAD cookie writes and PSHOLD/watchdog resets rebooted back into U-Boot, so they are not a reliable recovery path from this U-Boot context.

The current recovery path is a UART bootstrap through U-Boot's `mw.l` and `go` commands:

| Artifact | Path | Size | SHA-256 |
| --- | --- | --- | --- |
| UART stage0 loader | `tools/uart-stage0/build/stage0.bin` | `752` | `b4135ba64ff75793c9adafa120d80a77a11fb0138fa8b4c525a18db176817447` |
| Stage0 U-Boot paste script | `tools/uart-stage0/build/stage0-mw.txt` | generated | generated |
| Stage0 host sender | `tools/uart-stage0/send-payload.py` | source | source |

Stage0 protocol defaults:

| Item | Value |
| --- | --- |
| Stage0 load/entry | `0x82000000` |
| UART | GSBI5 UARTDM v1.3 at `0x16440000`, `115200 8n1` |
| Default payload | `out/fame/android4lumia-lk-build/build-msm8960/lk.bin` |
| Default payload load/entry | `0x88f00000` |

Build and use:

```sh
tools/uart-stage0/build.sh
tools/uart-stage0/send-payload.py --port /dev/ttyUSB0
```

If LK starts from RAM, immediately use LK fastboot to flash a persistent rescue APPSBL before rebooting. Restoring stock `UEFI.bin` gets back to BootMgr/FlashApp; flashing the LK padded `UEFI` candidate keeps a fastboot recovery APPSBL for more raw U-Boot bring-up.
