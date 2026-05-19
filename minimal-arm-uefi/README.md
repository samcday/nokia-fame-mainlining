# Minimal ARM UEFI Payload

This is a tiny freestanding ARM/Thumb UEFI application for the unlocked Nokia Lumia 520 / `fame` boot path.

It does not use `gnu-efi`. The EFI declarations are intentionally minimal and only cover the interfaces used by this payload.

## Build

```sh
make
make inspect
```

The default output is patched to match the stock Lumia firmware fallback loader's PE machine type:

```text
build/minimal-arm-uefi.efi
```

The intermediate unpatched LLVM output is kept as `build/minimal-arm-uefi-armnt.efi`. The final image keeps the same Thumb code but changes the PE Machine field from `IMAGE_FILE_MACHINE_ARMNT (0x1C4)` to `IMAGE_FILE_MACHINE_THUMB (0x1C2)`, matching stock `\efi\boot\bootarm.efi`.

The build expects LLVM COFF tools in `PATH`:

| Tool | Purpose |
| --- | --- |
| `clang` | Compiles Thumb ARM COFF object code. |
| `lld-link` | Links PE32 EFI application. |
| `llvm-readobj` | Inspects the resulting PE header. |

## Behavior

On entry, the payload:

1. Prints a short message through UEFI `ConOut` if available.
2. Leaves the UEFI watchdog unchanged for watchdog timing experiments.
3. Queries `EFI_GRAPHICS_OUTPUT_PROTOCOL` and prints GOP mode/base details in decimal if available.
4. Waits three seconds so the firmware console remains visible before any test pattern is drawn.
5. Draws a static test pattern through GOP `Blt(EfiBltVideoFill)` when `GOP_BLT_ENABLED` is `true`.
6. Waits another three seconds.
7. Prints a post-BLT checkpoint through UEFI `ConOut`.
8. Waits another three seconds.
9. Writes two small direct-store markers when `GOP_DIRECT_ENABLED` is `true`.
10. One marker uses GOP `PixelsPerScanLine` addressing; the other uses tight `width` addressing.
11. Prints byte offsets and readbacks, then cleans each marker range from the ARM data cache.
12. Prints post-clean readbacks and stalls forever.

The current dual-stride test build uses GOP BLT first as a known-good baseline, then uses small direct framebuffer markers plus ARMv7 data-cache clean by MVA. The two paths are independently gated by `GOP_BLT_ENABLED` and `GOP_DIRECT_ENABLED` in `main.c`.

The direct hardcoded framebuffer fallback was removed. The FFU-derived framebuffer facts remain useful for later Linux/simpledrm work:

Live Fame GOP observations so far:

| Field | Value |
| --- | --- |
| GOP mode | `480x800` |
| GOP `PixelsPerScanLine` | `800` |
| GOP pixel format | `1`, `PixelBlueGreenRedReserved8BitPerColor` |
| GOP framebuffer base | `0x80400000` / `2151677952` |
| GOP framebuffer size | `1536000`, exactly `480 * 800 * 4` |
| Working direct scanout stride | `480` pixels / `1920` bytes |

The firmware GOP `Blt(EfiBltVideoFill)` path renders cleanly. Direct scanout on this unit follows the tight framebuffer size rather than GOP `PixelsPerScanLine`, so full-height direct stores using stride `800` run past the reported framebuffer size and produce misleading/corrupt results.

Static framebuffer facts from the stock FFU ACPI/PCFG breadcrumbs:

| Field | Value |
| --- | --- |
| Base | `0x80400000` |
| Width | `480` |
| Height | `800` |
| Stride | `1920` bytes |
| Pixel format | 32-bit `a8r8g8b8`-style test pattern |

## Deployment Boundary

Building this payload is safe. Running it on the phone requires changing the EFIESP boot path or replacing an EFI binary there. Treat that as a destructive-device-state operation unless a verified backup/restore path is in hand.
