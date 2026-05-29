# Regulators And GPIO

Initial regulator/GPIO data comes from the msm8227-mainline Fame DTS and is not yet hardware-validated in this workspace.

## PMIC And Supplies

| Consumer | Supply Mapping | Source | Trust |
| --- | --- | --- | --- |
| eMMC SDCC1 `vmmc` | `pm8038_l5` | Fame DTS sketch; PM8038 L5 RPM resource support cross-checked below | C |
| eMMC SDCC1 `vqmmc` | `pm8038_l11` | Fame DTS sketch; PM8038 L11 RPM resource support cross-checked below | C |
| SDCC3 `vmmc` | `pm8038_l6` | Fame DTS | C |
| SDCC3 `vqmmc` | `pm8038_l22` | Fame DTS | C |
| USB HS PHY 3.3 V | `pm8038_l3` | Fame DTS sketch; PM8038 L3 RPM resource support cross-checked below | C |
| USB HS PHY 1.8 V | `pm8038_l4` | Fame DTS sketch; PM8038 L4 RPM resource support cross-checked below | C |
| WCNSS core | `pm8038_s1` | Fame DTS | C |
| WCNSS mx | `pm8038_l24` | Fame DTS | C |
| WCNSS px/io | `pm8038_l11` | Fame DTS | C |
| Synaptics VDD | `pm8038_l9` | Disabled Fame DTS sketch | C |
| Synaptics VIO | `pm8038_lvs2` | Disabled Fame DTS sketch | C |

## GPIO Clues

| Function | GPIO | Source | Trust |
| --- | --- | --- | --- |
| Power key | `PWIO` logical pin 16, not a PM8038 GPIO | Stock FFU `BTN0._CRS` / `PWIO._DSM`; decoded below | A |
| Volume up | PM8038 GPIO3, ACPI `PM01` pin 194 / `PM_GPIO03_CHGED_ST_IRQ_ID` | Stock FFU `BTN0._CRS` pin decode corroborates old Fame DTS function label | A for pin, C for label |
| Volume down | PM8038 GPIO8, ACPI `PM01` pin 199 / `PM_GPIO08_CHGED_ST_IRQ_ID` | Stock FFU `BTN0._CRS` pin decode corroborates old Fame DTS function label | A for pin, C for label |
| Camera snapshot / full-press | PM8038 GPIO10, ACPI `PM01` pin 201 / `PM_GPIO10_CHGED_ST_IRQ_ID` | Stock FFU `BTN0._CRS` pin decode corroborates old Fame DTS function label | A for pin, C for label |
| Camera focus / half-press | PM8038 GPIO11, ACPI `PM01` pin 202 / `PM_GPIO11_CHGED_ST_IRQ_ID` | Stock FFU `BTN0._CRS` pin decode corroborates old Fame DTS function label | A for pin, C for label |
| Touch IRQ | MSM GPIO11 | Disabled Fame DTS sketch | C |
| Touch reset | MSM GPIO52 | Disabled Fame DTS sketch | C |
| WLAN pins | MSM GPIO84-88 | Fame DTS | C |
| BT pins | MSM GPIO28, GPIO29, GPIO83 | Fame DTS | C |

## Stock FFU ACPI Breadcrumbs

| Function | FFU/ACPI Clue | Source | Trust |
| --- | --- | --- | --- |
| TLMM GPIO controller | `GIO0` HID `QCOM0500` | `dsdt.dsl:17194-17219` | A |
| PMIC GPIO / power-key controller | `PWIO` HID `QCOM0D20` | `dsdt.dsl:17222-17249` | A |
| Button controller | `BTN0` HID `QCOM0D60`, CID `PNP0C40`, resource buffer references `PWIO` and `PM01`; resource decode below | `dsdt.dsl:17323-17397`, `dsdt.aml` offsets below | A |
| SDCC3 card/resource GPIO | `SDC3` resource buffer includes `GIO0` pin 94 | `dsdt.dsl:18088-18118` | A, GPIO flags pending |
| Touch bus/GPIO shape | `TCH1` depends on `I2C3` and `GIO0`; resource buffer decodes to I2C address `0x4B`, `GpioInt` pin 11, and `GpioIo` pin 52 | `dsdt.dsl:21056-21085` | A, GPIO flags pending |

Do not overwrite DTS GPIO flags directly from raw `_CRS` bytes. Decode and verify ACPI flags, pulls, trigger type, polarity, and wake behavior first.

## Stock FFU Button Decode

The current workspace did not have `iasl` on `PATH` during the 2026-05-29
decode, so the button resources were decoded directly from the AML resource
descriptors. Source file:
`extracted/acpi-or-platform-config/RM-914-059S083/PLAT-files/ACPI/dsdt.aml`.

`BTN0` is `QCOM0D60` with `CID` `PNP0C40`. Its device object starts at AML
offset `0x0000e733`, and its `_CRS` resource payload is a 352-byte resource
template at `0x0000e771..0x0000e8d0`. Each physical/logical button has one
`GpioInt` descriptor followed by a matching `GpioIo` descriptor.

| Order | Function | Interrupt AML Offset | GPIO I/O AML Offset | ACPI Resource | PMIC Mapping | Flags |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Power key | `0x0000e771` | `0x0000e794` | `PWIO` pin 16 | Not PM8038 GPIO | `GpioInt(Edge, ActiveBoth, Shared, NoWake, PullUp)`, `PWIO._DSM` marks pin 16 asserted-high |
| 2 | Volume up | `0x0000e7b7` | `0x0000e7da` | `PM01` pin 194 | PM8038 GPIO3 | `GpioInt(Edge, ActiveBoth, SharedAndWake, PullDefault)`, debounce `0x1838` = 62 ms, asserted-low by default |
| 3 | Volume down | `0x0000e7fd` | `0x0000e820` | `PM01` pin 199 | PM8038 GPIO8 | `GpioInt(Edge, ActiveBoth, SharedAndWake, PullDefault)`, debounce 62 ms, asserted-low by default |
| 4 | Camera focus / half-press | `0x0000e843` | `0x0000e866` | `PM01` pin 202 | PM8038 GPIO11 | `GpioInt(Edge, ActiveBoth, Shared, NoWake, PullDefault)`, debounce 62 ms, asserted-low by default |
| 5 | Camera snapshot / full-press | `0x0000e889` | `0x0000e8ac` | `PM01` pin 201 | PM8038 GPIO10 | `GpioInt(Edge, ActiveBoth, SharedAndWake, PullDefault)`, debounce 62 ms, asserted-low by default |

`BTN0` also has two short methods after `_CRS`: `BNWP` returns buffer
`00 02 03 07 08` at AML payload offset `0x0000e8e6`, and `BNAS` returns
buffer `01 00 00 00 00` at AML payload offset `0x0000e900`. Their exact
Windows Phone semantics are still unknown; do not use them for Linux input
mapping without another source.

The `PM01` ACPI pin numbers are PMIC interrupt IDs, not DT GPIO specifier
numbers. The mapping is corroborated two ways:

| Fact | Source | Trust |
| --- | --- | --- |
| Downstream PMIC IRQ IDs number PM GPIO changed-state interrupts as `PM_GPIO01_CHGED_ST_IRQ_ID = 192`, `PM_GPIO03 = 194`, `PM_GPIO08 = 199`, `PM_GPIO10 = 201`, and `PM_GPIO11 = 202`. | `community/android4lumia-lk-msm8227/platform/msm8x60/include/platform/pmic.h:155-171` | C |
| Mainline `pinctrl-ssbi-gpio` translates PM8xxx GPIO IRQ specifiers as 1-based physical GPIO numbers and maps child hwirq to parent hwirq with `+ 0xc0`; `qcom,pm8038-gpio` exposes 12 GPIOs. | `linux/drivers/pinctrl/qcom/pinctrl-ssbi-gpio.c:53,683-696,707-724` | E |
| Downstream MSM8930 PM8038 setup configures key GPIO3/GPIO8/GPIO10/GPIO11 as inputs with 30 uA pull-ups, normal function, no output drive, and PM8038 L11 VIN; LK carries the same key GPIO input/pull setup. | `community/android4lumia-kernel-msm8x27/arch/arm/mach-msm/board-8930-pmic.c:72-76,147-153`; `community/android4lumia-lk-msm8227/platform/msm8960/gpio.c:187-199` | C |

Therefore, for future DT work using `qcom,pm8038-gpio`, the physical GPIO
specifier should be `3`, `8`, `10`, and `11` for the four non-power buttons,
not zero-based `2`, `7`, `9`, and `10`. The power key should be modeled through
the PMIC power-key/PWIO path, not as a PM8038 GPIO, unless live testing proves a
separate Linux binding is needed.

## MSM8930/PM8038 RPM Breadcrumbs

| Fact | Source | Trust |
| --- | --- | --- |
| MSM8930 RPM resource table includes PM8038 L3/L4/L5/L11 with active resource IDs 106/108/110/122, selectors 38/39/40/46, and status selectors 47/49/51/63. | `community/android4lumia-kernel-msm8x27/arch/arm/mach-msm/devices-8930.c:135-143`, `community/android4lumia-kernel-msm8x27/arch/arm/mach-msm/include/mach/rpm-8930.h:72-80,238-255,455-472` | C |
| The Samsung Express MSM8930 branch ports those same PM8038 resources into mainline-style RPM/regulator drivers and supports PM8038 `s4`, `l3`, `l4`, `l5`, and `l11`. | `samsung-expressltexx:drivers/mfd/qcom_rpm.c:341-347`, `samsung-expressltexx:drivers/regulator/qcom_rpm-regulator.c:918-924,950-958` | E |
| The Samsung Express board wires USB HS PHY supplies to PM8917 L4/L3 and supplies its board-specific ULPI init sequence from the board DTS. Fame keeps its ACPI-derived ULPI init sequence instead of copying Express values. | `samsung-expressltexx:arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:519-528`, `notes/hardware-inventory.md:35-36` | E/A |

Do not enable SDCC3 supplies from the old Fame DTS sketch yet. PM8038 L6/L22 are not covered by the current Express-derived RPM regulator support and SDCC3 card-detect GPIO flags remain undecoded from ACPI.

The current Fame DTS only instantiates PM8038 RPM regulators needed for first
boot cleanup: L3/L4 for USB HS PHY and L5/L11 for SDCC1/eMMC. These are
deliberately limited to the PM8038 resources now supported by the local
Express-derived RPM/regulator driver patch.

## Known DTS Issues

The old Fame DTS sketch used `drive-strengh` instead of `drive-strength` in
SDCC pinctrl groups. The minimal first-boot DTS does not carry those pinctrl
groups; fix the typo before reintroducing SDCC pinctrl.

## SDCC1 Pinctrl Breadcrumbs

Fame's internal eMMC already enumerates in Linux using the current SDCC1 node
and PM8038 L5/L11 supplies. The next cleanup is to stop relying on bootloader
pinmux state by adding the shared MSM8960-style TLMM node and board SDCC1
default/sleep states.

| Fact | Source | Trust |
| --- | --- | --- |
| Stock ACPI exposes TLMM as `GIO0` / `QCOM0500`; Samsung Express MSM8930 models the shared TLMM block as `qcom,msm8960-pinctrl` at `0x00800000`, size `0x4000`, 152 GPIOs, and GIC SPI 16. | `dsdt.dsl:17194-17219`, `samsung-expressltexx:arch/arm/boot/dts/qcom/qcom-msm8930.dtsi:443-452` | A/E |
| Mainline's MSM8960 TLMM binding and driver expose SDCC1 groups `sdc1_clk`, `sdc1_cmd`, and `sdc1_data` under `qcom,msm8960-pinctrl`. | `linux/Documentation/devicetree/bindings/pinctrl/qcom,msm8960-pinctrl.yaml:16-31,51-60`, `linux/drivers/pinctrl/qcom/pinctrl-msm8960.c:329-334,1212-1214,1238-1240` | E |
| Samsung Express SDCC1 default pinctrl uses clock drive strength 16 with bias disabled, command/data drive strength 10 with pull-ups, and sleep drive strength 2 for all SDCC1 groups. | `samsung-expressltexx:arch/arm/boot/dts/qcom/qcom-msm8930-samsung-expressltexx.dts:298-304,382-420` | E |

## PM8038 DSI Rails (L2, L8) RPM Resource Derivation

DSI bring-up adds PM8038 **L2** (`dsi_vdda` 1.2V) and **L8** (`dsi_vdc`/mainline `avdd`
2.8-3.0V) to the Express-derived RPM regulator driver. L11 (`dsi_vddio` 1.8V) is already
supported and always-on. Mainline `qcom_rpm_resource` is `{target_id, status_id, select_id,
size}` (`drivers/mfd/qcom_rpm.c:22-27`).

Downstream select IDs (`community/android4lumia-kernel-msm8x27/arch/arm/mach-msm/include/mach/rpm-8930.h:71,77`):
PM8038 L2 SEL=37, L8 SEL=43. These match mainline's existing PM8038 select_ids
(L3=38, L5=40, L11=46). Every entry of `msm8930_rpm_resource_table` obeys `target=2*sel+30`,
`status=2*sel-29`; the SEL=43 slot is confirmed directly by `QCOM_RPM_PM8917_LDO6 = {116, 57,
43, 2}` (`drivers/mfd/qcom_rpm.c:353`).

| Rail | Tuple `{target,status,select,size}` | Regulator type | Voltage | Trust |
| --- | --- | --- | --- | --- |
| PM8038 L2 | `{104, 45, 37, 2}` | `pm8921_nldo` | 1.2V | C, formula + downstream SEL |
| PM8038 L8 | `{116, 57, 43, 2}` | `pm8921_pldo` | 2.8-3.0V | C, confirmed via shared SEL=43 slot |

New dt-binding constants go after the current PM8917 block in
`include/dt-bindings/mfd/qcom-rpm.h` (next free indices). Regulator types mirror the Express
PM8917 choices: L2 (low-voltage) -> `pm8921_nldo`, L8 -> `pm8921_pldo`.

## U-Boot Fame Display Rail RPM Writes

The U-Boot MDP diagnostic path now needs the same DSI supply state as the
working kernel. The MSM8227 RPM node is `qcom,rpm-msm8930` at `0x00108000`,
with IPC routed through the KPSS/L2 syscon at `0x02011000 + 0x8`, bit 2
(`linux/arch/arm/boot/dts/qcom/qcom-msm8227.dtsi:99-103,178-184`).
Mainline's RPM driver maps status registers at the RPM base, control registers
at `+0x400`, and request registers at `+0x600`; it validates firmware version
3 and copies the three version words into control registers 0-2 before serving
children (`linux/drivers/mfd/qcom_rpm.c:613-617,646-665`).

For MSM8930 the request control layout is `req_ctx_off=3`, `req_sel_off=11`,
`ack_ctx_off=15`, `ack_sel_off=23`, `req_sel_size=4`, and `ack_sel_size=7`
(`linux/drivers/mfd/qcom_rpm.c:363-372`). A regulator request writes the
resource payload words at `req_regs[target_id + i]`, sets the selector bit in
the request selector array, writes active context bit 0, and triggers the IPC
bit; completion is reported through `ack_ctx_off`, with `BIT(31)` meaning RPM
rejected the request and `BIT(30)` being a notification that should not complete
the transaction (`linux/drivers/mfd/qcom_rpm.c:482-526,529-549`).

PM8038 LDOs use the RPM8960 LDO layout: word 0 contains the microvolt request
in bits 0-22 and the `bias-pull-down` bit in bit 23; word 1 carries load and
force-mode fields, which the current minimal U-Boot path leaves zero. The
kernel regulator code preserves the pull-down bit in the same cached request
word before writing the voltage on enable (`linux/drivers/regulator/qcom_rpm-regulator.c:106-115,189-203,286-303,676-695`).

The Fame panel/DSI supplies mirrored by the U-Boot diagnostic helper are:

| Rail | RPM target | RPM select | Word 0 | Source |
| --- | --- | --- | --- | --- |
| PM8038 L2 / `dsi_vdda` | 104 | 37 | `1200000 | BIT(23)` | `linux/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dts:42-46,165-168`; `linux/drivers/mfd/qcom_rpm.c:341-349` |
| PM8038 L8 / `avdd` | 116 | 43 | `2800000 | BIT(23)` | `linux/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dts:68-72,165-168`; `linux/drivers/mfd/qcom_rpm.c:341-349` |
| PM8038 L11 / `vddio` | 122 | 46 | `1800000 | BIT(23)` | `linux/arch/arm/boot/dts/qcom/qcom-msm8227-nokia-fame.dts:74-80,165-193`; `linux/drivers/mfd/qcom_rpm.c:341-349` |
