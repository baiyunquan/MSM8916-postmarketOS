#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
boot_image=${1:?Usage: configure-multiboard-boot.sh <boot-image> <dtb-output-directory>}
dtb_output=${2:?Usage: configure-multiboard-boot.sh <boot-image> <dtb-output-directory>}
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

test -s "$boot_image"
mkdir -p "$dtb_output"

read_compatible() {
	file=$1
	if command -v fdtget >/dev/null 2>&1; then
		fdtget -t s "$file" / compatible | awk '{print $1}'
	else
		"${DTC:-dtc}" -q -I dtb -O dts "$file" 2>/dev/null \
			| awk -F '"' '/^[[:space:]]*compatible =/ && !found { print $2; found = 1 }'
	fi
}

debugfs -R "dump /extlinux/extlinux.conf $work_dir/extlinux.conf" "$boot_image" >/dev/null 2>&1
[ "$(grep -c '^[[:space:]]*fdt ' "$work_dir/extlinux.conf")" -eq 1 ]
sed -E -i 's#^[[:space:]]*fdt .*$#\tfdt /dtbs/qcom/msm8916-thwc-ufi001c.dtb#' \
	"$work_dir/extlinux.conf"

debugfs -w -R 'rm /extlinux/extlinux.conf' "$boot_image" >/dev/null 2>&1
debugfs -w -R "write $work_dir/extlinux.conf /extlinux/extlinux.conf" "$boot_image" >/dev/null 2>&1
debugfs -w -R 'set_inode_field /extlinux/extlinux.conf mode 0100644' "$boot_image" >/dev/null 2>&1

for item in boards.conf README-BOARD-SELECTION.txt; do
	debugfs -w -R "rm /$item" "$boot_image" >/dev/null 2>&1 || true
done
debugfs -w -R "write $repo_root/config/boards.conf /boards.conf" "$boot_image" >/dev/null 2>&1
debugfs -w -R "write $repo_root/config/BOOT-README.txt /README-BOARD-SELECTION.txt" \
	"$boot_image" >/dev/null 2>&1
debugfs -w -R 'set_inode_field /boards.conf mode 0100644' "$boot_image" >/dev/null 2>&1
debugfs -w -R 'set_inode_field /README-BOARD-SELECTION.txt mode 0100644' \
	"$boot_image" >/dev/null 2>&1

while IFS='|' read -r board dtb _source compatible _display; do
	case "$board" in ''|'#'*) continue ;; esac
	output="$dtb_output/$dtb"
	debugfs -R "dump /dtbs/qcom/$dtb $output" "$boot_image" >/dev/null 2>&1
	test -s "$output" || { echo "Missing /dtbs/qcom/$dtb in $boot_image" >&2; exit 1; }
	actual=$(read_compatible "$output")
	[ "$actual" = "$compatible" ] || {
		echo "$board compatible mismatch: expected $compatible, got $actual" >&2
		exit 1
	}
done < "$repo_root/config/boards.conf"

debugfs -R "dump /extlinux/extlinux.conf $work_dir/verify-extlinux.conf" \
	"$boot_image" >/dev/null 2>&1
grep -Fq 'fdt /dtbs/qcom/msm8916-thwc-ufi001c.dtb' "$work_dir/verify-extlinux.conf"
[ "$(find "$dtb_output" -maxdepth 1 -type f -name '*.dtb' | wc -l)" -eq 19 ]

echo "Configured multi-board boot image and exported 19 DTBs"
