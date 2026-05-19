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
