# Scripts

Project-local helper scripts should live here once workflows are proven.

Initial candidates:

| Script | Purpose |
| --- | --- |
| `download-ffu.sh` | Wrapper around `lp-externals lumiadb download --model RM-914 --product-code 059S083`. |
| `extract-ffu.sh` | Extract GPT, ESP, selected boot partitions, and ACPI candidates from a stock FFU. |
| `build-dev-initrd.sh` | Tiny BusyBox/configfs CDC-ACM initramfs once kernel UDC is in scope. |

Top-level helpers currently live at repository root when they are the primary bring-up entry point:

| Script | Purpose |
| --- | --- |
| `build-u-boot-uefi-smoke.sh` | Builds the canonical Linux DTB, raw Fame U-Boot, and a padded UART smoke image for the stock `UEFI` partition. |
