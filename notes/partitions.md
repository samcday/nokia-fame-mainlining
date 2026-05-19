# Partitions

The stock FFU now provides the highest-trust offline GPT baseline for RM-914 / `059S083`. A fresh live GPT dump is still pending, so do not assume the current device exactly matches this table until `lp-externals gpt dump` is compared.

## Stock FFU GPT Header

Source command:

```sh
cargo run --manifest-path ~/src/lp-externals/Cargo.toml -- \
  ffu partitions extracted/ffu/RM-914/059S083/RM914_3058.50000.1425.0001_RETAIL_eu_euro2_218_01_452872_prd_signed.ffu
```

| Field | Value |
| --- | --- |
| Header offset | `0` |
| Revision | `0x00010000` |
| Header size | `92` |
| Current LBA | `1` |
| Backup LBA | `15155199` |
| First usable LBA | `34` |
| Last usable LBA | `15155166` |
| Disk GUID | `ae420040-13dd-41f2-ae7f-0dc35854c8d7` |
| Partition entries LBA | `2` |
| Partition entry count | `128` |
| Partition entry size | `128` |

## Stock FFU Partitions

| # | Name | First LBA | Last LBA | Sectors | Attrs |
| --- | --- | --- | --- | --- | --- |
| 1 | `DPP` | `4096` | `20479` | `16384` | `0x8000000000000000` |
| 2 | `MODEM_FSG` | `20480` | `26623` | `6144` | `0x8000000000000000` |
| 3 | `SSD` | `28672` | `28703` | `32` | `0x8000000000000000` |
| 4 | `SBL1` | `32768` | `35767` | `3000` | `0x8000000000000000` |
| 5 | `SBL2` | `36864` | `39863` | `3000` | `0x8000000000000000` |
| 6 | `SBL3` | `40960` | `45055` | `4096` | `0x8000000000000000` |
| 7 | `UEFI` | `45056` | `50055` | `5000` | `0x8000000000000000` |
| 8 | `RPM` | `53248` | `54247` | `1000` | `0x8000000000000000` |
| 9 | `TZ` | `57344` | `58343` | `1000` | `0x8000000000000000` |
| 10 | `WINSECAPP` | `61440` | `62463` | `1024` | `0x8000000000000000` |
| 11 | `BACKUP_SBL1` | `65536` | `68535` | `3000` | `0x8000000000000000` |
| 12 | `BACKUP_SBL2` | `69632` | `72631` | `3000` | `0x8000000000000000` |
| 13 | `BACKUP_SBL3` | `73728` | `77823` | `4096` | `0x8000000000000000` |
| 14 | `BACKUP_UEFI` | `77824` | `82823` | `5000` | `0x8000000000000000` |
| 15 | `BACKUP_RPM` | `86016` | `87015` | `1000` | `0x8000000000000000` |
| 16 | `BACKUP_TZ` | `90112` | `91111` | `1000` | `0x8000000000000000` |
| 17 | `BACKUP_WINSECAPP` | `94208` | `95231` | `1024` | `0x8000000000000000` |
| 18 | `UEFI_BS_NV` | `98304` | `98815` | `512` | `0x8000000000000000` |
| 19 | `UEFI_NV` | `102400` | `102911` | `512` | `0x8000000000000000` |
| 20 | `PLAT` | `106496` | `122879` | `16384` | `0x8000000000000000` |
| 21 | `EFIESP` | `131072` | `262143` | `131072` | `0x8000000000000000` |
| 22 | `MODEM_FS1` | `262144` | `268287` | `6144` | `0x8000000000000000` |
| 23 | `MODEM_FS2` | `270336` | `276479` | `6144` | `0x8000000000000000` |
| 24 | `UEFI_RT_NV` | `278528` | `279039` | `512` | `0x8000000000000000` |
| 25 | `UEFI_RT_NV_RPMB` | `282624` | `282879` | `256` | `0x8000000000000000` |
| 26 | `MMOS` | `286720` | `450399` | `163680` | `0x8000000000000000` |
| 27 | `MainOS` | `458752` | `5088511` | `4629760` | `0x0000000000000000` |
| 28 | `Data` | `5095424` | `15151103` | `10055680` | `0x8000000000000000` |

## Extracted Partition Images

| Partition | Local Image | Size | Format Notes |
| --- | --- | --- | --- |
| `EFIESP` | `extracted/partitions/RM-914-059S083/EFIESP.img` | `67108864` | FAT16, hidden sectors `131072`, sectors `131072`. |
| `PLAT` | `extracted/partitions/RM-914-059S083/PLAT.bin` | `8388608` | FAT12, hidden sectors `106496`, sectors `16384`. |
| `MMOS` | `extracted/partitions/RM-914-059S083/MMOS.img` | `83804160` | FAT16, hidden sectors `286720`, sectors `163680`. |
| `UEFI` | `extracted/partitions/RM-914-059S083/UEFI.bin` | `2560000` | Raw firmware data. |
| `SBL1` | `extracted/partitions/RM-914-059S083/SBL1.bin` | `1536000` | Raw firmware data. |
| `SBL2` | `extracted/partitions/RM-914-059S083/SBL2.bin` | `1536000` | Raw firmware data. |
| `SBL3` | `extracted/partitions/RM-914-059S083/SBL3.bin` | `2097152` | Raw firmware data. |
| `RPM` | `extracted/partitions/RM-914-059S083/RPM.bin` | `512000` | Raw firmware data. |
| `TZ` | `extracted/partitions/RM-914-059S083/TZ.bin` | `512000` | Raw firmware data. |
| `WINSECAPP` | `extracted/partitions/RM-914-059S083/WINSECAPP.bin` | `524288` | Raw firmware data. |

## EFIESP Contents

High-value visible files from `extracted/partitions/RM-914-059S083/EFIESP-files/`:

| Path | Notes |
| --- | --- |
| `/batt_soc100_950mA.efi` | Battery/charging EFI app candidate. |
| `/BATTERY.PROVISION` | Battery provisioning data. |
| `/boot/boot.sdi` | Windows boot support image. |
| `/efi/boot/bootarm.efi` | Default ARM UEFI boot path. |
| `/efi/Microsoft/Boot/BCD` | Windows Boot Configuration Data. |
| `/efi/Microsoft/Boot/Boot.stl` | Secure boot signature list style file. |
| `/Nokia/Security/Nokia_Production_PK.bin` | Nokia production platform key blob. |
| `/Nokia/Security/Nokia_RD_PK.bin` | Nokia R&D platform key blob. |
| `/Nokia/Security/production_db.bin` | Production allowlist database blob. |
| `/Nokia/Security/rd_db.bin` | R&D allowlist database blob. |
| `/Nokia/Security/SecureBootPolicy.p7b` | Secure boot policy blob. |
| `/Nokia/Security/SecureBootPolicy_test.p7b` | Test secure boot policy blob. |
| `/Windows/System32/Boot/efisimpleio.efi` | Windows boot support EFI app. |
| `/Windows/System32/Boot/ffuloader.efi` | FFU flashing loader. |
| `/Windows/System32/Boot/mmosloader.efi` | MMOS loader. |
| `/Windows/System32/Boot/mobilestartup.efi` | Mobile startup EFI app. |
| `/Windows/System32/Boot/resetphone.efi` | Reset phone EFI app. |
| `/Windows/System32/Boot/sigcheck.efi` | Signature-checking EFI app. |

## PLAT Contents

High-value visible files from `extracted/acpi-or-platform-config/RM-914-059S083/PLAT-files/`:

| Path | Notes |
| --- | --- |
| `/ACPI/dsdt.aml` | Main ACPI table, decompiled to `dsdt.dsl`. |
| `/ACPI/ssdt.aml` | Nokia SSDT, decompiled to `ssdt.dsl`. |
| `/SMBIOS/SMBIOS.CFG` | Qualcomm sample-style SMBIOS config; contains placeholder serial-like strings, do not copy into public notes. |
| `/UEFI_CFG.TXT` | Empty in this extraction. |
| `/logo1.bmp` | Boot logo image. |
| `/logo2.bmp` | Boot logo image. |
| `/Windows/Packages/DsmFiles/Nokia.ACPI.FAME_ROW.dsm.xml` | Package manifest naming Fame ROW ACPI. |

## Known Android/pmaports Hints

From `community/android4lumia-device-fame/BoardConfig.mk`:

| Field | Value |
| --- | --- |
| `BOARD_USERDATAIMAGE_PARTITION_SIZE` | `6149881344` |
| `BOARD_FLASH_BLOCK_SIZE` | `131072` |

From `/var/home/sam/src/pmaports/device/downstream/device-nokia-fame/deviceinfo`:

| Field | Value |
| --- | --- |
| Flash method | `fastboot` |
| Boot image generation | `true` |
| Page size | `4096` |
| Base | `0x80200000` |
| Kernel offset | `0x00008000` |
| Ramdisk offset | `0x02000000` |
| Second offset | `0x00f00000` |
| Tags offset | `0x00000100` |

## Next Steps

1. Capture live GPT with `lp-externals gpt dump`.
2. Compare live partition names, start sectors, sizes, and EFIESP location against the stock FFU table above.
3. Keep raw dumps under `extracted/partitions/`; only commit metadata and comparisons.
