# FFU Inventory

Stock RM-914 / `059S083` LumiaDB artifacts were downloaded into ignored local storage under `extracted/ffu/`. Keep these files out of git; commit only inventories, hashes, and extraction notes.

## Downloaded Artifacts

| Blob | Local Path | Size | SHA-256 |
| --- | --- | --- | --- |
| Stock FFU | `extracted/ffu/RM-914/059S083/RM914_3058.50000.1425.0001_RETAIL_eu_euro2_218_01_452872_prd_signed.ffu` | `1674575872` | `c323a5e337b4b3e9d114db351adf1411c0359b391bdbaaf0f1a0a47a5a5af819` |
| Emergency package | `extracted/ffu/RM-914/059S083/RM-914.zip` | `1469102` | `584a0e13c023e19ffc82cc51229bb820d70cda2b839e4cc72cdd5846de2311e7` |
| Engineering SBL3 | `extracted/ffu/RM-914/059S083/Engineering-SBL3-Lumia-520-620-625-720-1320.bin` | `350080` | `e42732ee6b6a6876dfb0e9d093c4601d8b3773533f7a1523ee0710c475193fc9` |

Original URLs from LumiaDB plan in `~/src/lp-externals/UNLOCKING.md`:

| Blob | URL |
| --- | --- |
| Stock FFU | `https://api.lumiadb.com/RM-914/RM914_3058.50000.1425.0001_RETAIL_eu_euro2_218_01_452872_prd_signed.ffu` |
| Emergency package | `https://api.lumiadb.com/RM-914/RM-914.zip` |
| Engineering SBL3 | `https://api.lumiadb.com/SBL3/Engineering-SBL3-Lumia-520-620-625-720-1320.bin` |

## Download Command

```sh
cargo run --manifest-path ~/src/lp-externals/Cargo.toml -- \
  lumiadb download --model RM-914 --product-code 059S083 --output extracted/ffu
```

## FFU Metadata

Command:

```sh
cargo run --manifest-path ~/src/lp-externals/Cargo.toml -- \
  ffu info extracted/ffu/RM-914/059S083/RM914_3058.50000.1425.0001_RETAIL_eu_euro2_218_01_452872_prd_signed.ffu
```

| Field | Value |
| --- | --- |
| File size | `1674575872` |
| Chunk size | `131072` |
| Platform ID | `Nokia.MSM8227.P6036` |
| Security header | `524288` bytes |
| Image header | `131072` bytes |
| Store header | `262144` bytes |
| Header size | `917504` |
| Payload size | `1673658368` |
| Total chunks | `12769` |
| Mapped disk chunks | `59184` |

The FFU platform ID is shorter than the live-unit value `Nokia.MSM8227.P6036.1.2` recorded in `notes/live-device-inventory.md`.

## Extracted Local Artifacts

| Artifact | Local Path | Size | Notes |
| --- | --- | --- | --- |
| Primary GPT with PMBR | `extracted/partitions/RM-914-059S083/gpt-primary-with-pmbr.bin` | `17408` | Raw sector metadata only. |
| `EFIESP` image | `extracted/partitions/RM-914-059S083/EFIESP.img` | `67108864` | FAT16, hidden sectors `131072`. |
| `PLAT` image | `extracted/partitions/RM-914-059S083/PLAT.bin` | `8388608` | FAT12, hidden sectors `106496`. |
| `MMOS` image | `extracted/partitions/RM-914-059S083/MMOS.img` | `83804160` | FAT16, hidden sectors `286720`. |
| `UEFI` image | `extracted/partitions/RM-914-059S083/UEFI.bin` | `2560000` | Raw firmware data. |
| `SBL1` | `extracted/partitions/RM-914-059S083/SBL1.bin` | `1536000` | Firmware inventory only. |
| `SBL2` | `extracted/partitions/RM-914-059S083/SBL2.bin` | `1536000` | Firmware inventory only. |
| `SBL3` | `extracted/partitions/RM-914-059S083/SBL3.bin` | `2097152` | Firmware inventory only. |
| `RPM` | `extracted/partitions/RM-914-059S083/RPM.bin` | `512000` | Firmware inventory only. |
| `TZ` | `extracted/partitions/RM-914-059S083/TZ.bin` | `512000` | Firmware inventory only. |
| `WINSECAPP` | `extracted/partitions/RM-914-059S083/WINSECAPP.bin` | `524288` | Firmware inventory only. |

Emergency package contents were unpacked to `extracted/firmware/RM-914-059S083/emergency/`:

| File |
| --- |
| `FAST8930_RM914.hex` |
| `RM914_msimage_v1.0.mbn` |
| `RM914_prg_v1.0.hex` |

## Extraction Commands

Offline FFU inspection commands are provided by `~/src/lp-externals`:

```sh
FFU=extracted/ffu/RM-914/059S083/RM914_3058.50000.1425.0001_RETAIL_eu_euro2_218_01_452872_prd_signed.ffu
cargo run --manifest-path ~/src/lp-externals/Cargo.toml -- ffu partitions "$FFU"
cargo run --manifest-path ~/src/lp-externals/Cargo.toml -- ffu extract "$FFU" EFIESP extracted/partitions/RM-914-059S083/EFIESP.img
cargo run --manifest-path ~/src/lp-externals/Cargo.toml -- ffu extract "$FFU" PLAT extracted/partitions/RM-914-059S083/PLAT.bin
cargo run --manifest-path ~/src/lp-externals/Cargo.toml -- ffu extract-sectors "$FFU" 0 34 extracted/partitions/RM-914-059S083/gpt-primary-with-pmbr.bin
```

`mcopy` works for FAT image extraction, but quote mtools paths under zsh. Use `"::*"`, not bare `::*`.

## Tool Availability

| Tool | Status |
| --- | --- |
| `binwalk` | Present |
| `sgdisk` | Present |
| `mkbootimg` | Present |
| `mcopy` | Present |
| `7z` | Present |
| `iasl` | Present, version `20260408` |
