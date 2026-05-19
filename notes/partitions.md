# Partitions

No FFU or live GPT dump has been copied into this workspace yet.

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
2. Extract FFU GPT with `lp-externals ffu partitions` after downloading the FFU.
3. Compare partition names, start sectors, sizes, and EFIESP location.
4. Record only partition metadata here; keep raw dumps under `extracted/partitions/`.
