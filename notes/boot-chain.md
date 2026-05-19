# Boot Chain

The current unit has been unlocked with `~/src/lp-externals`, but this workspace has not yet validated an ergonomic chainloader path.

## Current Understanding

| Stage | Status | Notes |
| --- | --- | --- |
| Lumia BootMgr USB | Candidate | Exposes `0421:066e` and `NOK*` protocol. |
| FlashApp/PhoneInfoApp | Candidate | `lp-externals` can switch/read inventory safely. |
| EFIESP | Pending | Needs FFU extraction and/or live mass-storage/partition access. |
| ARM UEFI payload | Pending | Need to prove what the unlocked UEFI environment will load from ESP. |
| U-Boot as ARM EFI app | Blocked | Current U-Boot `CONFIG_EFI_APP` path is x86-gated. |
| Raw ARM32 U-Boot payload | Hypothesis | Samsung Express patches are reusable, but handoff/debug route is not proven. |
| U-Boot fastboot | High risk | MSM8227 USB is old ChipIdea/ULPI-era; no UART fallback. |

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

## ESP/UEFI Investigation Plan

1. Extract `EFIESP` from the stock FFU.
2. Inventory EFI binaries, BCD, boot file names, and boot manager layout.
3. Check whether the unlocked UEFI environment loads unsigned/test-signed EFI binaries from ESP.
4. Build a minimal ARM UEFI hello-world payload before attempting U-Boot.
5. Only after payload handoff is proven, decide whether to port U-Boot ARM EFI app support or use a raw handoff stub.
