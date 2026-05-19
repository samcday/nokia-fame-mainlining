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
2. Disables the UEFI watchdog timer if available.
3. Repeatedly paints the FFU-derived framebuffer at `0x80400000`.

Framebuffer assumptions are from the stock FFU ACPI/PCFG breadcrumbs:

| Field | Value |
| --- | --- |
| Base | `0x80400000` |
| Width | `480` |
| Height | `800` |
| Stride | `1920` bytes |
| Pixel format | 32-bit `a8r8g8b8`-style test pattern |

## Deployment Boundary

Building this payload is safe. Running it on the phone requires changing the EFIESP boot path or replacing an EFI binary there. Treat that as a destructive-device-state operation unless a verified backup/restore path is in hand.
