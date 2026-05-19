# BootMgr Protocol

Primary local reference: `~/src/lp-externals/PROTOCOL.md` and Rust source under `~/src/lp-externals/src/`.

## Safe Initial Commands

| Command | Tool Command | Purpose | Safety |
| --- | --- | --- | --- |
| `NOKD` | `lp-externals stay-awake` | Disable BootMgr timeout watchdog | Non-flashing |
| `NOKV` | `lp-externals identify` | Read app/protocol info | Read-only |
| `NOKT` | `lp-externals gpt dump` | Read GPT payload | Read-only |
| `NOKP` | `lp-externals switch phone-info` | Switch to PhoneInfoApp | Mode-changing, non-flashing |
| `NOKXPH` | `lp-externals phone-info read TYPE/CTR` | Read PhoneInfo variables | Read-only in PhoneInfoApp |

Known current unit values from `~/src/lp-externals/UNLOCKING.md`:

| Field | Value |
| --- | --- |
| BootMgr app | `1.16` |
| FlashApp protocol/app | `1.15` / `1.28` |
| PhoneInfo TYPE | `RM-914` |
| PhoneInfo CTR | `059S083` |

## Do Not Run Without Explicit Approval

| Command/Tool Path | Reason |
| --- | --- |
| `factory-reset` / `NOKG` | Destructive modem factory reset. |
| `stock-restore` | Destructive signed FFU flashing. |
| `soft-brick` | Intentionally corrupts boot data to enter emergency mode. |
| `disable-secure-boot` / `NOKF` | Raw sector writes to GPT/ESP/NV areas. |
| `NOKXBW`, `NOKXBK`, `NOKXBH`, `NOKXBU` | Manufacturing/SecureBoot state/key writes. |

## Next Capture

Run these after connecting the phone in BootMgr mode, then paste sanitized output into `notes/live-device-inventory.md`:

```sh
cargo run --manifest-path ~/src/lp-externals/Cargo.toml -- stay-awake
cargo run --manifest-path ~/src/lp-externals/Cargo.toml -- identify
cargo run --manifest-path ~/src/lp-externals/Cargo.toml -- gpt dump
```
