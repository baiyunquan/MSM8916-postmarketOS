#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
destination=${1:?Usage: stage-device-trees.sh <destination>}
source_dir="$repo_root/debian-dtbs/dtbs"

test -f "$source_dir/msm8916-generic-m9s.dts"
mkdir -p "$destination"

cp "$repo_root/config/openstick-dtbs.list" "$destination/"
cp "$source_dir/msm8916-mifi.dtsi" "$source_dir/msm8916-sp970.dtsi" "$destination/"

while IFS= read -r dtb; do
	[ -n "$dtb" ] || continue
	cp "$source_dir/${dtb%.dtb}.dts" "$destination/"
done < "$repo_root/config/openstick-dtbs.list"

cp "$source_dir/msm8916-fy-mf800.dtb" "$source_dir/msm8916-jz01-45-v33.dtb" "$destination/"
patch --batch --forward -d "$destination" -p1 < "$repo_root/patches/device-trees-6.12.patch"

echo "Staged Debian device trees for the postmarketOS 6.12.1-msm8916 kernel in $destination"
