# Extracted Artifacts

This directory is for local proprietary or blob-heavy artifacts and is intentionally ignored by git.

Recommended layout:

```text
extracted/
  ffu/                         stock FFUs and LumiaDB downloads
  partitions/                  raw partition dumps from FFU or live device
  firmware/                    unpacked firmware blobs
  acpi-or-platform-config/     AML/DSL/PCFG/XML and derived platform config
```

Commit inventories, hashes, paths, and extraction commands in `notes/`. Do not commit FFUs, partition images, or firmware payloads.
