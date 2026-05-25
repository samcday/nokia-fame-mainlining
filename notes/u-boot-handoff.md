# U-Boot Handoff Notes

Use this note to continue Fame U-Boot stabilization separately from kernel bring-up.

## Current Working Kernel Boot Path

The current Linux test path is persistent U-Boot fastboot booting an Android boot-image v2 wrapper:

```sh
fastboot -s 7cda982 oem 'run:setenv fdt_high 0xffffffff; setenv initrd_high 0xffffffff; printenv fdt_high initrd_high'
fastboot -s 7cda982 oem console
fastboot -s 7cda982 boot out/fame/fame-linux-fastboot.img
```

Observed working handoff on 2026-05-22:

```text
Using Device Tree in place at 829e9000, end 829ece94
Booting Linux on physical CPU 0x0
earlycon: msm_serial_dm0 at MMIO 0x16440000
Kernel command line: console=ttyMSM0,115200n8 earlycon loglevel=8 ignore_loglevel rdinit=/init
```

The Linux boot image now uses `Image.gz`, not ARM `zImage`. U-Boot gunzips the payload to `0x80208000`. The Android header reports the DTB at `0x88400000` and ramdisk at `0x88600000`, but U-Boot's Android DTB lookup still maps the DTB from its location inside the downloaded boot image near `0x829e9000`.

The current builder adds `panic=5` to the kernel command line so deliberate mini-initrd console failures reboot automatically.

## Required U-Boot Environment

`fdt_high=0xffffffff` is required for the current boot path. This is U-Boot's special in-place FDT mode. It avoids relocating the Linux DTB into the low `0x80204000` hole, where Linux either hangs or loses early output.

`initrd_high=0xffffffff` is required so U-Boot reserves and passes the Android boot-image ramdisk in place instead of allocating a second high copy.

`fdt_high=0x88400000` did not work. It is a maximum-address cap, not an exact placement. With the generic Snapdragon LMB preallocations active, the allocator still selected `0x80204000` as the available address below the cap.

## U-Boot Cleanup Candidates

Fame should eventually default these env vars during late init, but that U-Boot change is deferred. For now the live test procedure sets them explicitly before each kernel boot:

```text
fdt_high=0xffffffff
initrd_high=0xffffffff
```

The generic Snapdragon `board_late_init()` allocates large LMB-backed runtime buffers (`loadaddr`, `kernel_addr_r`, `ramdisk_addr_r`, `kernel_comp_addr_r`, `fastboot_addr_r`, and others). On this 512 MiB device split into `0x80200000..0x88dfffff` and `0x90000000..0x9fffffff`, those reservations can starve boot-time FDT relocation and push the FDT into unsafe low memory. A Fame-specific address policy or smaller reservations would be cleaner.

The volatile U-Boot test image should remain separate from Linux kernel testing. The build helper emits an Android boot image with raw PIE `u-boot-dtb.bin` as its kernel payload:

```sh
fastboot -s 7cda982 oem 'run:setenv fastboot_bootcmd abootimg addr 0x82000000\; bootm start 0x82000000\; bootm loados\; go 0x82001000'
fastboot -s 7cda982 boot out/fame/u-boot/u-boot-fame-fastboot.img
```

The `go` address is the Android boot-image kernel load address, not the APPSBL link address. `abootimg addr` keeps the procedure compatible with currently flashed images by making `bootm start` and `bootm loados` parse the downloaded image at the fastboot buffer rather than the default `$loadaddr`; newer U-Boot sources also set this before running custom `fastboot_bootcmd`. `CONFIG_POSITION_INDEPENDENT=y` lets the nested U-Boot start at `0x82001000` while the persistent APPSBL image remains linked for `0x88f00000`.

## Memory Facts

Live U-Boot `bdinfo` previously reported:

| Region | Value |
| --- | --- |
| DRAM bank 0 | `0x80200000..0x88dfffff`, `0x08c00000` bytes |
| DRAM bank 1 | `0x90000000..0x9fffffff`, `0x10000000` bytes |
| Relocated U-Boot | `0x9ffd0000` |
| U-Boot control FDT | `0x8ffb0490` |

The final kernel log confirms Linux receives those two memory ranges and starts at `0x80200000`, leaving the MSM shared memory below that out of `/memory`.
