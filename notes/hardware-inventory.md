# Hardware Inventory

Facts here are grouped by provenance. Community facts are hypotheses until confirmed by FFU, live device reads, or hardware testing.

## High-Trust Current Unit Facts

From `~/src/lp-externals/UNLOCKING.md`:

| Fact | Value |
| --- | --- |
| Product type | `RM-914` |
| Product code | `059S083` |
| Platform ID | `Nokia.MSM8227.P6036.1.2` |
| BootMgr app | `1.16` |
| FlashApp protocol/app | `1.15` / `1.28` |

## Stock FFU-Derived Facts

From `RM914_3058.50000.1425.0001_RETAIL_eu_euro2_218_01_452872_prd_signed.ffu` and extracted PLAT ACPI:

| Area | Fact | Source | Trust |
| --- | --- | --- | --- |
| FFU platform | `Nokia.MSM8227.P6036` | `notes/ffu-inventory.md` | A |
| GPT | 28 partitions, disk GUID `ae420040-13dd-41f2-ae7f-0dc35854c8d7` | `notes/partitions.md` | A |
| EFIESP | FAT16 at stock GPT LBA `131072`, size `67108864` | `notes/partitions.md` | A |
| PLAT | FAT12 at stock GPT LBA `106496`, size `8388608` | `notes/partitions.md` | A |
| ACPI identity | DSDT OEM `QCOMM`, SSDT OEM `NOKIA`, table `MSM8930` | `notes/acpi.md` | A |
| Display | PCFG panel `Teisko`, 480x800 24bpp DSI, two lanes, pixel clock `52598700` Hz | `notes/display.md` | A |
| Storage controllers | ACPI `SDC1` and `SDC3` use HID `QCOM7002`; `SDC1` has child `EMMC` with `_RMV` returning `Zero`; `SDC3` resource buffer includes `GIO0` pin 94 | `dsdt.dsl:18048-18118` | A, GPIO flags pending |
| USB function | ACPI `UFN1` uses HID `QCOM01C0`, base `0x12500000`, and `PHYC` config method | `dsdt.dsl:18376-18440` | A |
| USB PHY init | ACPI `UFN1.PHYC` returns vendor ULPI register writes `(0x81, 0x38)` and `(0x82, 0x14)`; for Linux-style `qcom,init-seq` this is represented as offsets `<0x01 0x38 0x02 0x14>` from ULPI vendor base `0x80` | `dsdt.dsl:18422-18438`, `linux/drivers/phy/qualcomm/phy-qcom-usb-hs.c:144-146` | A |
| USB controller shape | Android4Lumia LK for its MSM8960/MSM8227 target defines `MSM_USB_BASE` as `0x12500000`, `INT_USB_HS` as `GIC_SPI_START + 100`, and USB HS1 clock/reset registers matching the mainline MSM8960 GCC binding; mainline MSM8960 DTS uses the same `qcom,ci-hdrc` two-window register shape, GIC SPI 100, USB HS1 clocks/reset, and nested ULPI `qcom,usb-hs-phy-msm8960` PHY. | `out/fame/android4lumia-lk-msm8227-src/platform/msm8960/include/platform/iomap.h:72`, `out/fame/android4lumia-lk-msm8227-src/platform/msm8960/include/platform/irqs.h:44-53`, `out/fame/android4lumia-lk-msm8227-src/platform/msm8960/include/platform/clock.h:97-100`, `linux/arch/arm/boot/dts/qcom/qcom-msm8960.dtsi:505-534` | C/E |
| Debug UART | Device UART output is now available after hardware rework. Host-to-device TX is suspected broken after reassembly, but device-to-host RX is enough for kernel/U-Boot logs. | Live hardware observation, 2026-05-20 | B |
| Debug UART mapping | Android4Lumia LK maps MSM8227/MSM8627 boards to `LINUX_MACHTYPE_8627_*`, then initializes GSBI5 UARTDM with GSBI base `0x16400000` and UART base `0x16440000`; the Samsung MSM8930 sibling DTS uses the same GSBI5/UARTDM addresses, `qcom,msm-uartdm-v1.3` compatible, GIC SPI 154 interrupt, and GSBI5 GCC clocks. | `community/android4lumia-lk-msm8227:target/msm8960/init.c:331-334,398-408`, `/var/home/sam/src/samsung-expressltexx/linux/arch/arm/boot/dts/qcom/qcom-msm8930.dtsi:354-377` | C/E |
| Touch resources | ACPI `TCH1` HID `NOKIA_TOUCH`, depends on `I2C3` and `GIO0`; resource buffer decodes to I2C address `0x4B`, `GpioInt` pin 11, and `GpioIo` pin 52 | `dsdt.dsl:21056-21085` | A, GPIO flags pending |
| Sensors | SSDT has accelerometer `KXTNK`, ALS/PRX candidates `QPDS_T900_*` and `LTR_554ALS_02_*` on `IC12` | `ssdt.dsl:30-582` | A, population decision pending |
| WLAN/BT/FM | ACPI `RIVA` HID `QCOM0E20` with nested `BTH0`, `QWLN`, `FMT0`, and `NOKIA_WLAN_PROXY` | `dsdt.dsl:17710-17801` | A |
| GPS | ACPI nested `GPS` HID `QCOM_GPS` under `SMD0` | `dsdt.dsl:17597-17610` | A |
| Vibra | ACPI `VIB1` HID `NOKIA_VIBRA_DIME`; SSDT also has `VIB2` HID `ODDT_VIB` | `dsdt.dsl:21031-21043`, `ssdt.dsl:594-606` | A |

Use these FFU-derived facts as breadcrumbs before changing DTS. ACPI resource buffers still need complete decoding for IRQ polarity, GPIO flags, supply sequencing, and exact Linux bindings.

## Community Device Sketch

From `community/android4lumia-device-fame/README.md`:

| Area | Claim | Trust |
| --- | --- | --- |
| SoC | `1.0GHz Dual-Core MSM8227` | C |
| GPU | Adreno 305 | C |
| RAM | 512 MB | C |
| Storage | 8 GB Samsung/Hynix | C |
| Battery | 1430 mAh BL-5J | C |
| Touch | Synaptics | C |
| Display | 4.0 inch 800x480 Orise-based | C |
| Camera | 5 MP SMIA75 | C |

Variants listed by Android4Lumia include RM-913, RM-914, RM-915, RM-917, RM-997, and RM-998.

## Existing Fame DTS Facts

From `linux/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dts`:

| Area | Current DTS State | Trust |
| --- | --- | --- |
| Model/compatible | `Nokia Lumia 520`, `nokia,fame`, `qcom,msm8930`, `qcom,msm8227` | C |
| Memory | `0x80200000 0x08c00000`, `0x90000000 0x10000000` | C |
| Console | GSBI5 UART as `serial0` | C, untestable until UART exists |
| PMIC | Includes `pm8038.dtsi` | C |
| Keys | PM8038 GPIO 3/8/10/11 for volume/camera keys | C |
| eMMC | SDCC1 with PM8038 L5/L11 supplies | C |
| External SD | SDCC3 with PM8038 L6/L22 supplies, currently `non-removable` | C, suspicious |
| USB | `usb1` enabled as `peripheral`, HS PHY uses ACPI-derived ULPI init sequence; regulator supplies still not modeled | A/C, supply sequencing pending |
| WCNSS/Riva | WLAN pins GPIO84-88, BT pins GPIO28/29/83, WCN3660-style iris | C |
| Touch | Disabled Synaptics RMI4 sketch at I2C `0x4b`, IRQ GPIO11, reset GPIO52 | C, disabled |

The stock DSDT `TCH1` resource buffer independently points at `I2C3`, decodes to I2C address `0x4B`, and references `GIO0` pins 11 and 52. This corroborates the disabled DTS sketch's bus/address/GPIO shape but does not by itself identify the controller as Synaptics or validate regulator rails.

## postmarketOS Clues

From `/var/home/sam/src/pmaports/device/downstream/device-nokia-fame/deviceinfo`:

| Area | Claim | Trust |
| --- | --- | --- |
| Screen | 480x800 | C |
| External storage | `true` | C |
| Boot image base | `0x80200000` | C |
| Kernel offset | `0x00008000` | C |
| Ramdisk offset | `0x02000000` | C |
| Tags offset | `0x00000100` | C |
| Page size | `4096` | C |

## Community Kernel Config Clues

From `community/android4lumia-kernel-msm8x27/arch/arm/configs/lineage_fame_defconfig`:

| Area | Config | Trust |
| --- | --- | --- |
| Touch | `CONFIG_TOUCHSCREEN_SYNAPTICS_I2C_RMI*` | C |
| Display | `CONFIG_FB_MSM_MIPI_ORISE_VIDEO_FWVGA_PT_PANEL` | C |
| USB gadget | `CONFIG_USB_CI13XXX_MSM`, `CONFIG_USB_G_ANDROID` | C |
| eMMC/SD | SDCC1 8-bit, SDCC3 enabled | C |
| WLAN | `CONFIG_PRIMA_WLAN=m`, WCNSS configs | C |
| Sensor | `CONFIG_SENSORS_LTR553` | C |
