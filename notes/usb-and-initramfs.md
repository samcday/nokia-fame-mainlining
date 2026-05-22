# USB And Initramfs Gadget

Use this file when reasoning about Linux HSUSB1/UDC tests, the local mini-initrd, configfs CDC-ACM, or Android boot-image layout for persistent U-Boot `fastboot boot`.

## Kernel Boot Image

Current test image builder:

| Item | Value |
| --- | --- |
| Helper | `./build-linux-fastboot.sh` |
| Output | `out/fame/fame-linux-fastboot.img` |
| Kernel payload | Gzip-compressed ARM `Image` at `out/fame/Image.gz` |
| DTB payload | `qcom-msm8227-nokia-fame.dtb` in the Android boot-image v2 DTB area |
| Ramdisk | `out/fame/minitrd.cpio.gz` from `./build-minitrd.sh` |
| U-Boot command | Set `fdt_high=0xffffffff` and `initrd_high=0xffffffff`, open `oem console`, then `fastboot boot out/fame/fame-linux-fastboot.img` |

Boot layout values currently used by `build-linux-fastboot.sh`:

| Field | Value | Breadcrumb |
| --- | --- | --- |
| Base | `0x80200000` | pmaports Fame deviceinfo copied in `notes/partitions.md:126-137`; current use in `build-linux-fastboot.sh:80-85` |
| Kernel offset | `0x00008000` | pmaports Fame deviceinfo copied in `notes/partitions.md:126-137`; current use in `build-linux-fastboot.sh:80-85` |
| Tags/FDT offset | `0x02000000` | Express method avoids raw ARM early page-table clobber at `/var/home/sam/src/samsung-expressltexx/build-lk2nd-bootable.sh:84-92`; current use in `build-linux-fastboot.sh:80-85` |
| DTB offset | `0x08200000` | Android boot-image v2 exposes a DTB payload to U-Boot; the working live path uses `fdt_high=0xffffffff` so U-Boot passes the selected FDT in place instead of relocating it into low memory. Current use in `build-linux-fastboot.sh:80-85` and `build-linux-fastboot.sh:160-172` |
| Ramdisk offset | `0x08400000` | Keeps the in-place ramdisk high and away from the downloaded image/kernel source window at `0x82000000`; current use in `build-linux-fastboot.sh:80-85` and `build-linux-fastboot.sh:160-172` |
| Page size | `4096` | pmaports Fame deviceinfo copied in `notes/partitions.md:126-137`; current use in `build-linux-fastboot.sh:80-85` |
| Header version | `2` | U-Boot's Android DTB lookup requires header version >= 2; current use in `build-linux-fastboot.sh:160-172` |

Default kernel command line:

```text
console=ttyMSM0,115200n8 earlycon loglevel=8 ignore_loglevel panic=5 rdinit=/init
```

Current use: `build-linux-fastboot.sh:87-88`.

Persistent U-Boot needs enough bootm decompression/copy space for the Fame `Image.gz` payload. The Fame APPSBL, PIE APPSBL, and LK-chain fastboot defconfigs set `CONFIG_SYS_BOOTM_LEN=0x04000000` at `u-boot/configs/nokia_fame_appsbl_defconfig:23-25`, `u-boot/configs/nokia_fame_appsbl_pie_defconfig:23-25`, and `u-boot/configs/nokia_fame_lk_fastboot_defconfig:23-25`.

The first hardware test with this layout got past DTB selection and the bootm
size limit, then failed with `Unable to allocate memory 0x80208000 for loading
OS`. That exposed a conflict between the old DTS `simple-framebuffer` reserved
region at `0x80400000..0x807fffff` and the ARM kernel load/decompression window.
The raw U-Boot fastboot path does not provide a proven live display handoff, so
`linux/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dts` no longer reserves
the framebuffer for this first UART/UDC boot path.

The next hardware test got past kernel load and then failed with `ramdisk -
allocation error`. U-Boot had already copied the Android boot-image ramdisk to
the header-requested address `0x88600000`, then `boot_ramdisk_high()` tried to
allocate a second high ramdisk copy and failed. The current live procedure sets
`initrd_high=0xffffffff` before `fastboot boot`, which selects U-Boot's in-place
initrd path and reserves the already-copied ramdisk instead of relocating it.

A later hardware test reached `Starting kernel ...` but produced no early kernel
output. U-Boot had relocated the FDT to `0x80204000`, directly below the ARM
zImage entry, which is not a decompressor-safe location. To avoid both the low
FDT placement and ARM zImage self-decompressor quirks, the current builder uses
`Image.gz`, lets U-Boot gunzip it to `0x80208000`, and moves DTB/ramdisk
placement to `0x88400000`/`0x88600000`.

The mini-initrd intentionally fails fast if it cannot attach to a usable console.
The default kernel command line includes `panic=5` so those init panics reboot
the phone without requiring physical power removal.

## Mini Initrd

The local mini-initrd is intentionally a test harness, not upstream board data. It is built by `./build-minitrd.sh` from `minitrd/` with mkosi, postmarketOS edge, ARMv7 packages, BusyBox, `devmem2`, and `evtest`.

Runtime behavior in `minitrd/mkosi.extra/init`:

| Behavior | Current Use |
| --- | --- |
| Mounts `devtmpfs`, `proc`, `sysfs`, `devpts`, `tmpfs`, `debugfs`, and `configfs` | `minitrd/mkosi.extra/init:13-47` |
| Uses `/dev/ttyMSM0` as the preferred interactive UART console | `minitrd/mkosi.extra/init:23-34`, `minitrd/mkosi.extra/init:157-170` |
| Waits briefly for a UDC, then creates a configfs CDC-ACM gadget when one appears | `minitrd/mkosi.extra/init:89-155` |
| Starts a shell on `/dev/ttyGS0` after binding the ACM gadget | `minitrd/mkosi.extra/init:56-87`, `minitrd/mkosi.extra/init:146` |

USB descriptor values used by the test gadget:

| Field | Value | Rationale |
| --- | --- | --- |
| `idVendor` | `0x1d6b` | Linux Foundation test-style gadget ID, not a Nokia production ID. |
| `idProduct` | `0x0104` | Linux Foundation Multifunction Composite Gadget ID. |
| Product string | `Lumia 520 CDC ACM` | Human-readable test identifier. |
| MaxPower | `100` | Conservative bus-powered test descriptor. |

## Kernel Config

The mini-initrd ACM path requires `CONFIG_USB_CONFIGFS_ACM=y`. Fame now carries that in `linux/arch/arm/configs/qcom_defconfig` next to the existing configfs gadget options.

Current use: `linux/arch/arm/configs/qcom_defconfig:197-204`.

## First Test Criteria

1. Kernel reaches `ttyMSM0` console or earlycon output.
2. `/sys/class/udc` exists in the mini-initrd.
3. The mini-initrd logs `CDC-ACM gadget bound to ...`.
4. The host sees a new ACM device and can open the BusyBox shell on `/dev/ttyACM*`.

## Host Serial Access

Host USB serial permissions are handled by a local udev rule:

```udev
SUBSYSTEM=="tty", KERNEL=="ttyUSB[0-9]*", TAG+="uaccess"
SUBSYSTEM=="tty", KERNEL=="ttyACM[0-9]*", TAG+="uaccess"
```

Current installed path: `/etc/udev/rules.d/70-usb-serial-uaccess.rules`.

Two connected FTDI UART adapters currently report the same USB serial number,
so `/dev/serial/by-id/usb-FTDI_FT232R_USB_UART_A50285BI-if00-port0` is not a
safe selector. Use `/dev/serial/by-path/` instead. During the 2026-05-22 Fame
Linux boot test, the Fame UART adapter was:

```text
/dev/serial/by-path/pci-0000:67:00.0-usb-0:4:1.0-port0
```

The other connected FTDI adapter was:

```text
/dev/serial/by-path/pci-0000:67:00.0-usb-0:5:1.0-port0
```

## Build Verification

Local verification completed on 2026-05-22 before the MSM8930 RPM/TSENS
follow-up:

```sh
git -C linux diff --check
bash -n build-minitrd.sh
bash -n build-linux-fastboot.sh
sh -n minitrd/mkosi.extra/init
./build-linux-fastboot.sh
unpack_bootimg --boot_img out/fame/fame-linux-fastboot.img --out out/fame/unpack-linux-fastboot
fdtget -l out/fame/linux-build/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dtb /
fdtget -l out/fame/linux-build/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dtb /clocks
```

`unpack_bootimg` confirmed Android boot magic, header version `2`, kernel load address `0x80208000`, ramdisk load address `0x88600000`, tags load address `0x82200000`, DTB address `0x88400000`, DTB size `3733`, page size `4096`, and the expected command line with `panic=5`. `fdtget -l` confirmed the root DTB nodes are `clocks`, `cpus`, `soc`, `aliases`, `chosen`, and `memory@80200000`, with no `reserved-memory` node in the current first-boot DTB. The `/clocks` children are `cxo_board` and `sleep_clk`, matching the names consumed by the MSM8960 GCC board-clock helper.

The kernel build config selected the ACM gadget dependencies:

| Config | Value | Build Config Location |
| --- | --- | --- |
| `CONFIG_USB_F_ACM` | `y` | `out/fame/linux-build/.config:5317` |
| `CONFIG_USB_U_SERIAL` | `y` | `out/fame/linux-build/.config:5318` |
| `CONFIG_USB_CONFIGFS_ACM` | `y` | `out/fame/linux-build/.config:5327` |

Built artifacts from that run:

| Artifact | Size | SHA-256 |
| --- | --- | --- |
| `out/fame/fame-linux-fastboot.img` | `10395648` | `4c47d2864b71d6ba21b78d113f3c458b12297745fd317208763b76f7b5403929` |
| `out/fame/Image.gz` | `9464622` | `3b75685849c98cc7b70a6a94825bd61e3aec31d9c926cd02f4ee85f23bcd116d` |
| `out/fame/linux-build/arch/arm/boot/Image` | `24920512` | `9dd13fd6e12c8804f06dd047886f9c1586c201d49e256ac429462c59122d1056` |
| `out/fame/minitrd.cpio.gz` | `919708` | `8f3487ea0e1793a0f76c05f65962799587fef808939ca5a3f1af621fd2431f98` |
| `out/fame/linux-build/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dtb` | `3733` | `83a29c321ef6bdca421814a35c46dd396a31bbfee094dcad05ab6d99a834907d` |

Local verification completed on 2026-05-22 after porting the MSM8930-style
RPM/PM8038/TSENS support from the Samsung Express branch:

```sh
git -C linux diff --check
./build-linux-fastboot.sh
unpack_bootimg --boot_img out/fame/fame-linux-fastboot.img --out out/fame/unpack-linux-fastboot
fdtget -l out/fame/linux-build/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dtb /soc
fdtget -l out/fame/linux-build/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dtb /soc/rpm@108000/regulators
fdtget -l out/fame/linux-build/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dtb /soc/clock-controller@900000
fdtget -t bx out/fame/linux-build/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dtb /soc/usb@12500000/ulpi/phy qcom,init-seq
```

`unpack_bootimg` confirmed Android boot magic, header version `2`, kernel load
address `0x80208000`, ramdisk load address `0x88600000`, tags load address
`0x82200000`, DTB address `0x88400000`, DTB size `5724`, page size `4096`,
and the expected command line with `panic=5`.

`fdtget` confirmed `/soc/rpm@108000/regulators` contains PM8038 `l3`, `l4`,
`l5`, and `l11`; `/soc/clock-controller@900000` contains the `thermal-sensor`
child; and the Fame board DTB still carries the ACPI-derived USB PHY init
sequence as bytes `01 38 02 14`.

The targeted `dtbs_check` follow-up was blocked by the host toolchain, not the
tree:

```text
ERROR: dtschema minimum version is v2023.9
```

Built artifacts from the MSM8930 RPM/TSENS follow-up run:

| Artifact | Size | SHA-256 |
| --- | --- | --- |
| `out/fame/fame-linux-fastboot.img` | `10403840` | `0d7205e888ff5a81d7e83d667e9b70b2aadabab24ae3f522aa40b0c7c497ca30` |
| `out/fame/Image.gz` | `9466118` | `a014a794b22a699e178084c180816b138cae66ad94b31e0163b4e635f07ce55b` |
| `out/fame/minitrd.cpio.gz` | `919705` | `7c18d7980eb62c1388f56aea81a010487b32f5fb79c19e18e7c0669b72641920` |
| `out/fame/linux-build/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dtb` | `5724` | `992d1ec61a4516f1aaa2fdbbfe8203c59c606dd200c4930e1773621dcd18bf16` |

## Hardware Test Results

Non-flashing boot command used on 2026-05-22:

```sh
fastboot -s 7cda982 oem 'run:setenv fdt_high 0xffffffff; setenv initrd_high 0xffffffff; printenv fdt_high initrd_high'
fastboot -s 7cda982 oem console
fastboot -s 7cda982 boot out/fame/fame-linux-fastboot.img
```

Result: the rebuilt image reached Linux, full MSM UART probe, `/dev/ttyMSM0`,
and the mini-initrd. The original `/dev/ttyMSM0` blocker was fixed by the
`cxo_board`/`sleep_clk` node-name change.

Key UART lines:

```text
Kernel command line: console=ttyMSM0,115200n8 earlycon loglevel=8 ignore_loglevel panic=5 rdinit=/init
msm_serial 16440000.serial: msm_serial: detected port #0
msm_serial 16440000.serial: uartclk = 1843200
msm_serial: driver initialized
[minitrd] fame BusyBox initramfs
[minitrd] USB device controllers:
lrwxrwxrwx ... ci_hdrc.0 -> ../../devices/platform/soc/12500000.usb/ci_hdrc.0/udc/ci_hdrc.0
[minitrd] CDC-ACM gadget bound to ci_hdrc.0
[minitrd] interactive shell on /dev/ttyMSM0
[minitrd] starting USB serial shell on /dev/ttyGS0
```

The remaining USB/gadget result is only initrd-side proof. Host-side Fame ACM
enumeration was not confirmed in this run because another connected board also
exports a Linux Foundation `1d6b:0104` CDC-ACM gadget. At the time of checking,
the only `ttyACM` by-id gadget descriptor present was
`usb-Samsung_Galaxy_Express_CDC_ACM_expressltexx-if00`, not the expected Fame
descriptor from the current initrd.

Two follow-up blockers appeared in the log:

| Issue | Evidence |
| --- | --- |
| USB PHY power-on fails | `phy phy-ci_hdrc.0.ulpi.0: phy poweron failed --> -22` |
| TSENS probe oopses | `PC is at init_common+0x0/0x58c`, `LR is at tsens_probe+0x140/0x4a4` |

The `gcc-msm8960` driver no longer fails with duplicate `cxo_board`; it now
continues far enough to call TSENS and logs `tsens_probe: init failed` before
the later deferred-probe oops.

Retest after the MSM8930 RPM/PM8038/TSENS patch succeeded. `boot-2.log` is not
tracked because `*.log` files are ignored, but the relevant result was:

```text
qcom_rpm 108000.rpm: RPM firmware 3.0.16842945
l3: Bringing 0uV into 3075000-3075000uV
l4: Bringing 0uV into 1800000-1800000uV
l5: Bringing 0uV into 2950000-2950000uV
l11: Bringing 0uV into 1800000-1800000uV
mmc0: new high speed MMC card at address 0001
mmcblk0: mmc0:0001 008G92 7.28 GiB
[minitrd] CDC-ACM gadget bound to ci_hdrc.0
[minitrd] interactive shell on /dev/ttyMSM0
```

The earlier TSENS oops, dummy regulator messages, USB PHY `poweron failed
--> -22`, and MMCI voltage-negotiation failure did not reappear. Remaining
non-fatal log warts are the USB PHY/RPM regulator supplier device-link warning,
`l3: voltage operation not allowed` while binding the gadget, live GPT backup
header mismatch warnings, early UART garbage during console handoff, and only
CPU0 coming online.

Retest after adding MSM8227 TLMM, Fame SDCC1/eMMC pinctrl, and dropping the
overlapping standalone `qcom,pshold` node succeeded. The final rebuilt image was
booted non-destructively from persistent U-Boot fastboot on 2026-05-22 with:

```sh
fastboot -s 7cda982 oem 'run:setenv fdt_high 0xffffffff; setenv initrd_high 0xffffffff'
fastboot -s 7cda982 boot out/fame/fame-linux-fastboot.img
```

Built artifacts from this run:

| Artifact | Size | SHA-256 |
| --- | --- | --- |
| `out/fame/fame-linux-fastboot.img` | `10403840` | `bb02a4f4de68963aebd4df5107b57d0b865c0e04141476f7e3093a4a97e1867c` |
| `out/fame/Image.gz` | `9466058` | `e4e7cc4bf0efedf35fd8e2df2c4ee6fd51494a51ba5fb78017191ee0dd27a552` |
| `out/fame/linux-build/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dtb` | `6560` | `f42d89dd578f3b3aadd32b62d3b2a6ac407be249eb2380b936bc81be1764a1d0` |
| `out/fame/minitrd.cpio.gz` | `919702` | `61079d35122450a946d7535f8cb92c4b5530fd53aef4bead2b4be3a004863b08` |

Relevant UART result:

```text
Linux version 7.1.0-rc4-00059-g734e9790ac25
msm_serial 16440000.serial: msm_serial: detected port #0
qcom_rpm 108000.rpm: RPM firmware 3.0.16842945
l5: Bringing 0uV into 2950000-2950000uV
l11: Bringing 0uV into 1800000-1800000uV
mmci-pl18x 12400000.mmc: DMA channels RX dma0chan1, TX dma0chan2
mmc0: new high speed MMC card at address 0001
mmcblk0: mmc0:0001 008G92 7.28 GiB
mmcblk0boot0: mmc0:0001 008G92 4.00 MiB
mmcblk0boot1: mmc0:0001 008G92 4.00 MiB
mmcblk0rpmb: mmc0:0001 008G92 512 KiB, chardev (238:0)
[minitrd] CDC-ACM gadget bound to ci_hdrc.0
[minitrd] interactive shell on /dev/ttyMSM0
```

The intermediate TLMM-only boot showed `msm-restart 800820.restart: error
-EBUSY` because the standalone `qcom,pshold` node overlapped the TLMM resource.
After dropping that node, the `msm-restart` failure no longer appeared; TLMM's
`ps_hold` restart hook owns the register instead. Issuing `reboot -f` through
the initrd CDC-ACM shell returned the phone to persistent U-Boot fastboot as
`7cda982 Android Fastboot`. Host-side Fame CDC-ACM enumeration is now also
confirmed through the stable by-id symlink
`usb-Nokia_Lumia_520_CDC_ACM_fame-if00`.

Targeted `dtbs_check` remains blocked by the host toolchain:

```text
ERROR: dtschema minimum version is v2023.9
```
