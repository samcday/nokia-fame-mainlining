# ACPI And Platform Config

No ACPI tables have been extracted yet.

## Why This Matters

Windows Phone FFUs may contain ACPI/AML tables and Nokia/Microsoft platform configuration that replace the missing OEM Linux BSP as a board-fact source. For display, the highest-value artifact is likely a Lumia panel PCFG XML blob embedded in DSDT.

## Prior Art

`prior-art/mainline4lumia-scripts/scripts/acpi_panel_extractor.py` expects a decompiled Lumia DSDT, searches for `Name (PCFG,`, and writes the embedded XML bytes to an output file.

## Tool Status

`iasl` was not installed during bootstrap. Install it before ACPI decompile work.

## Search Plan

After FFU extraction, search for AML/ACPI candidates:

```sh
rg -a -n "DSDT|SSDT|ACPI|PCFG|Name \\(PCFG|QCOM|NOK|MSFT|I2C|GPIO|SPMI|PMIC" extracted
```

If AML files are found:

```sh
iasl -d extracted/acpi-or-platform-config/*.aml
python3 prior-art/mainline4lumia-scripts/scripts/acpi_panel_extractor.py \
  extracted/acpi-or-platform-config/dsdt.dsl \
  extracted/acpi-or-platform-config/panel-pcfg.xml
```
