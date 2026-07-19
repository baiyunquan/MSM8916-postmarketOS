#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output_dir=${1:?Usage: build-bootloaders.sh <output-directory>}
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

mkdir -p "$output_dir"
cp -a "$repo_root/pmos-example/src/qhypstub" "$work_dir/qhypstub"
make -C "$work_dir/qhypstub" CROSS_COMPILE=aarch64-linux-gnu-
python3 "$repo_root/pmos-example/src/qtestsign/qtestsign.py" hyp \
	"$work_dir/qhypstub/qhypstub.elf" -o "$output_dir/hyp.mbn"

build_aboot() {
	name=$1
	bundle=$2
	compatible=$3
	lk2nd="$work_dir/lk2nd-$name"
	cp -a "$repo_root/pmos-example/src/lk2nd" "$lk2nd"
	printf '\nDEFINES += USE_TARGET_HS200_CAPS=1\n' >> "$lk2nd/project/lk1st-msm8916.mk"
	make -C "$lk2nd" \
		LK2ND_BUNDLE_DTB="$bundle" \
		LK2ND_COMPATIBLE="$compatible" \
		TOOLCHAIN_PREFIX=arm-none-eabi- \
		lk1st-msm8916
	python3 "$repo_root/pmos-example/src/qtestsign/qtestsign.py" aboot \
		"$lk2nd/build-lk1st-msm8916/emmc_appsboot.mbn" \
		-o "$output_dir/aboot-$name.mbn"
}

build_aboot thwc-ufi001c msm8916-512mb-mtp.dtb thwc,ufi001c
build_aboot thwc-uf896 msm8916-512mb-qrd-skuh.dtb thwc,uf896
build_aboot yiming-uz801v3 msm8916-512mb-mtp.dtb yiming,uz801-v3

echo "Built qhypstub and the three lk1st variants supported by upstream postmarketOS"
