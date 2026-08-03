#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
pmaports=${1:?Usage: prepare-pmaports.sh <pmaports-directory>}
expected_revision=${PMAPORTS_REV:-1ce58c5ae1b7573c6471959c4ab406391eefb103}
package_dir="$pmaports/device/testing/linux-postmarketos-qcom-msm8916"
gadget_aport_source="$repo_root/config/rndis-gadget"
gadget_aport="$pmaports/device/testing/postmarketos-msm8916-rndis-gadget"

actual_revision=$(git -C "$pmaports" rev-parse HEAD)
if [ "$actual_revision" != "$expected_revision" ]; then
	echo "Expected pmaports $expected_revision, found $actual_revision" >&2
	exit 1
fi

test -f "$package_dir/APKBUILD"
test -f "$pmaports/device/testing/device-zhihe-generic/APKBUILD"
test -f "$gadget_aport_source/APKBUILD"
patch --batch --forward -d "$pmaports" -p1 < "$repo_root/patches/pmaports-linux-multiboard.patch"
# The pin predates upstream e5536561, but the binary mirror it installs from does
# not. Without this, get_nonfree_packages() asks apk for a subpackage the mirror
# no longer publishes and the install aborts.
patch --batch --forward -d "$pmaports" -p1 < "$repo_root/patches/pmaports-device-zhihe-nonfree.patch"
if grep -Fq 'nonfree' "$pmaports/device/testing/device-zhihe-generic/APKBUILD"; then
	echo "device-zhihe-generic still references a nonfree subpackage" >&2
	exit 1
fi
"$repo_root/scripts/stage-device-trees.sh" "$package_dir"

if [ -e "$gadget_aport" ]; then
	echo "Unexpected existing pmaports package: $gadget_aport" >&2
	exit 1
fi
mkdir -p "$gadget_aport"
cp -a "$gadget_aport_source"/. "$gadget_aport"/
(
	cd "$gadget_aport"
	# APKBUILD is not itself a checksum manifest; extract the source checksum
	# lines in the same shape sha512sum expects.
	sed -n '/^[[:space:]]*[0-9a-f]\{128\}[[:space:]]/p' APKBUILD \
		| sed 's/^[[:space:]]*//' | sha512sum -c -
)

echo "Prepared the 19-board kernel and RNDIS gadget pmaports overlays"
