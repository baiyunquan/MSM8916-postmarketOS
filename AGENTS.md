# Repository Agent Guide

## Mission and acceptance boundary

This repository builds one postmarketOS split boot/root image for 19 MSM8916
boards. Every supported DTB must exist in `/dtbs/qcom` inside the ext2 boot
image, while `/extlinux/extlinux.conf` selects one DTB with a single `fdt`
line. CI success means compilation and structural validation; do not claim
hardware boot or peripheral support without evidence from a physical board.

## Repository ownership

- Root-owned files are the workflows, `config/`, `patches/`, `scripts/`, and
  documentation. Implement changes there.
- `pmos-example` and `debian-dtbs` are pinned provenance/reference submodules.
  Do not edit files inside either submodule. Update a gitlink only as an
  intentional, separately reviewed dependency change.
- `config/boards.conf` is the canonical 19-board public mapping. Its fields are
  `board-id|dtb-file|source|compatible|display-name`.
- `config/openstick-dtbs.list` is the kernel Makefile list for the 14
  source-ported boards. A board with source type `dts` must appear in both
  files; `native` and `dtb` entries must not appear in this list.

## Fixed upstream contract

- pmbootstrap: `ce76febabd983db6445fa9a8b75d601970b2f436`
- pmaports: `6fb3a1e5eb21c809891645a2ba5ae11fa788e032`
- kernel tag: `v6.12.1-msm8916`
- pmOS reference: `fe4289d03aaf95fd2325e81b12ff02b55b70e868`
- Debian DT reference: `ef731fa31eefdf5730f87e31d9aecafe61159ed2`

Changing a pin requires reapplying the pmaports overlay, compiling all 19
DTBs, rebuilding the full image, and updating README provenance. Never make a
workflow clone a moving upstream branch.

## Device-tree porting rules

- Reuse the kernel-native `msm8916-ufi.dtsi`; do not stage the older copy from
  `debian-dtbs`.
- Reuse the kernel-native UFI001C, UF896, and UZ801 V3 DTS files.
- Stage the 14 board DTS files plus `msm8916-mifi.dtsi` and
  `msm8916-sp970.dtsi` from `debian-dtbs` with
  `scripts/stage-device-trees.sh`.
- Keep version-specific changes in `patches/device-trees-6.12.patch`. The
  current patch removes unavailable SP970 UART pinctrl labels, uses the modern
  `id-gpios` spelling, and adapts MF32 LED/USB references to the native 6.12.1
  UFI include.
- MF800 and JZ01-45-V33 are binary-only inputs. Validate their DTB syntax and
  root compatible strings, but do not describe them as source-rebuilt.

## Required checks

Before committing changes, run at minimum:

```sh
for script in scripts/*.sh; do bash -n "$script"; done
shellcheck scripts/*.sh
git diff --check
```

For any device-tree, manifest, pmaports, or kernel change, also run:

```sh
bash scripts/validate-dtbs.sh /path/to/linux-v6.12.1-msm8916 /tmp/validated-dtbs
```

The command must produce exactly 19 DTBs and verify each first root compatible
against `config/boards.conf`. A full release is acceptable only after the build
workflow also verifies the boot image, `SHA256SUMS`, Actions Artifact, and
GitHub Release asset.

## Image and release invariants

- Keep one `zhihe-generic-boot.img` and one `zhihe-generic-root.img`; do not
  duplicate the rootfs per board.
- Default extlinux to
  `/dtbs/qcom/msm8916-thwc-ufi001c.dtb`, an upstream-supported baseline.
- Preserve `boards.conf` and `README-BOARD-SELECTION.txt` in the boot image.
- The tarball must include 19 exported DTBs, source revision metadata, and
  checksums for every file.
- Releases remain prereleases until physical-device boot results justify a
  stable release. Never publish passwords, tokens, firmware backups, IMEI/NV
  data, or user-provided proprietary partitions.
- Do not automate flashing. Documentation must retain the EDL backup and
  `tz`/`hyp` mismatch warnings.
