#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
kernel_dir=${1:?Usage: validate-dtbs.sh <linux-kernel-directory> [output-directory]}
output_dir=${2:-}
qcom_dir="$kernel_dir/arch/arm64/boot/dts/qcom"
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT

"$repo_root/scripts/stage-device-trees.sh" "$staging"
cp "$staging"/*.dts "$staging"/*.dtsi "$qcom_dir/"

while IFS= read -r dtb; do
	[ -n "$dtb" ] || continue
	if ! grep -Fq "$dtb" "$qcom_dir/Makefile"; then
		printf 'dtb-%s\t+= %s\n' "\$(CONFIG_ARCH_QCOM)" "$dtb" >> "$qcom_dir/Makefile"
	fi
done < "$repo_root/config/openstick-dtbs.list"

make -C "$kernel_dir" ARCH=arm64 defconfig >/dev/null
while IFS= read -r dtb; do
	[ -n "$dtb" ] || continue
	make -C "$kernel_dir" ARCH=arm64 "qcom/$dtb" -j"${JOBS:-4}"
done < "$repo_root/config/openstick-dtbs.list"

for dtb in msm8916-thwc-uf896.dtb msm8916-thwc-ufi001c.dtb msm8916-yiming-uz801v3.dtb; do
	make -C "$kernel_dir" ARCH=arm64 "qcom/$dtb" -j"${JOBS:-4}"
done

dtc_command=$(command -v dtc || true)
if [ -z "$dtc_command" ]; then
	dtc_command="$kernel_dir/scripts/dtc/dtc"
fi

read_compatible() {
	file=$1
	if command -v fdtget >/dev/null 2>&1; then
		fdtget -t s "$file" / compatible | awk '{print $1}'
	else
		"$dtc_command" -q -I dtb -O dts "$file" 2>/dev/null \
			| awk -F '"' '/^[[:space:]]*compatible =/ && !found { print $2; found = 1 }'
	fi
}

for dtb in msm8916-fy-mf800.dtb msm8916-jz01-45-v33.dtb; do
	"$dtc_command" -q -I dtb -O dts -o /dev/null "$staging/$dtb"
done

board_count=$(grep -cv '^#' "$repo_root/config/boards.conf")
[ "$board_count" -eq 19 ] || { echo "Expected 19 boards, found $board_count" >&2; exit 1; }

if [ -n "$output_dir" ]; then
	mkdir -p "$output_dir"
	while IFS='|' read -r board dtb source compatible _display; do
		case "$board" in ''|'#'*) continue ;; esac
		case "$source" in
			dtb) cp "$staging/$dtb" "$output_dir/$dtb" ;;
			dts|native) cp "$qcom_dir/$dtb" "$output_dir/$dtb" ;;
			*) echo "Unknown source type $source for $board" >&2; exit 1 ;;
		esac
		actual=$(read_compatible "$output_dir/$dtb")
		[ "$actual" = "$compatible" ] || {
			echo "$board compatible mismatch: expected $compatible, got $actual" >&2
			exit 1
		}
	done < "$repo_root/config/boards.conf"
fi

echo "Validated all 19 MSM8916 device trees"
