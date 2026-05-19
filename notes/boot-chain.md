# Boot Chain

The current unit has been unlocked with `~/src/lp-externals`, but this workspace has not yet validated an ergonomic chainloader path.

## Current Understanding

| Stage | Status | Notes |
| --- | --- | --- |
| Lumia BootMgr USB | Candidate | Exposes `0421:066e` and `NOK*` protocol. |
| FlashApp/PhoneInfoApp | Candidate | `lp-externals` can switch/read inventory safely. |
| EFIESP | Extracted from stock FFU | FAT16 image at stock GPT LBA `131072`, size `67108864`. |
| ARM UEFI payload | Pending live test | Need to prove what the unlocked UEFI environment will load from ESP. |
| U-Boot as ARM EFI app | Blocked | Current U-Boot `CONFIG_EFI_APP` path is x86-gated. |
| Raw ARM32 U-Boot payload | Hypothesis | Samsung Express patches are reusable, but handoff/debug route is not proven. |
| U-Boot fastboot | High risk | MSM8227 USB is old ChipIdea/ULPI-era; no UART fallback. |

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
