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
| USB | `usb1` enabled as `otg`, HS PHY supplied by PM8038 L3/L4 | C |
| WCNSS/Riva | WLAN pins GPIO84-88, BT pins GPIO28/29/83, WCN3660-style iris | C |
| Touch | Disabled Synaptics RMI4 sketch at I2C `0x4b`, IRQ GPIO11, reset GPIO52 | C, disabled |

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
