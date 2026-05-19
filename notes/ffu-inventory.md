# FFU Inventory

No stock FFU was present locally during bootstrap.

Known LumiaDB plan from `~/src/lp-externals/UNLOCKING.md`:

| Blob | URL | Size Noted |
| --- | --- | --- |
| Stock FFU | `https://api.lumiadb.com/RM-914/RM914_3058.50000.1425.0001_RETAIL_eu_euro2_218_01_452872_prd_signed.ffu` | `1674575872` |
| Emergency package | `https://api.lumiadb.com/RM-914/RM-914.zip` | `1469102` |
| Engineering SBL3 | `https://api.lumiadb.com/SBL3/Engineering-SBL3-Lumia-520-620-625-720-1320.bin` | `350080` |

## Download Command

Use local `lp-externals` if download is needed:

```sh
cargo run --manifest-path ~/src/lp-externals/Cargo.toml -- \
  lumiadb download --model RM-914 --product-code 059S083 --output extracted/ffu
```

Expected FFU path after download:

```text
extracted/ffu/RM-914/059S083/RM914_3058.50000.1425.0001_RETAIL_eu_euro2_218_01_452872_prd_signed.ffu
```

## First Extraction Targets

| Target | Purpose |
| --- | --- |
| GPT | Compare FFU partition table with live `NOKT` readback. |
| `EFIESP` | Inspect UEFI boot files, BCD, possible bootloader payload path. |
| `UEFI` | Firmware image and string/config hunting. |
| `SBL1`, `SBL2`, `SBL3`, `TZ`, `RPM`, `WINSECAPP` | Firmware inventory and version/provenance only; do not patch here. |
| ACPI/AML/DSDT/SSDT candidates | Search for PCFG/panel/platform resource data. |

## Tool Availability Noted During Bootstrap

| Tool | Status |
| --- | --- |
| `binwalk` | Present |
| `sgdisk` | Present |
| `mkbootimg` | Present |
| `mcopy` | Present |
| `7z` | Present |
| `iasl` | Missing |
