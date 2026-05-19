# Source Trust

This project has no known Nokia/Microsoft GPL Linux BSP for Fame. Treat community Android sources as reconstructed hardware enablement, not as an OEM oracle.

## Trust Tiers

| Tier | Source | Examples | Usage |
| --- | --- | --- | --- |
| A | Stock FFU-derived facts | GPT, EFIESP contents, UEFI apps, AML/DSDT/SSDT, PCFG XML, registry/config blobs | Prefer over all other sources. |
| B | Live read-only device facts | BootMgr `NOKV`, BootMgr/FlashApp `NOKT`, PhoneInfo `TYPE`/`CTR`, FlashApp read-only params | High trust for this physical RM-914 unit. |
| C | Community reconstruction | Android4Lumia device/kernel/LK, postmarketOS device packages | Hypothesis source; validate before enabling hardware. |
| D | Adjacent Lumia work | Mainline4Lumia scripts, WOA Lumia950XL notes, WPinternals protocol source | Method/source-code reference, not board truth. |
| E | Sibling Qualcomm boards | Sony Xperia M `nicki`, MSM8930 Samsung boards, MSM8226 Lumias | Generic SoC/style reference only. |

## Current Unit Facts

From `~/src/lp-externals/UNLOCKING.md`:

| Fact | Value | Trust |
| --- | --- | --- |
| Product type | `RM-914` | B |
| Product code | `059S083` | B |
| Platform ID | `Nokia.MSM8227.P6036.1.2` | B |
| BootMgr app | `1.16` | B |
| FlashApp protocol/app | `1.15` / `1.28` | B |
| LumiaDB FFU | `RM914_3058.50000.1425.0001_RETAIL_eu_euro2_218_01_452872_prd_signed.ffu` | B, pending local download |

Do not record IMEI in this repository.
