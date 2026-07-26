#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
pmaports=${1:?Usage: prepare-pmaports.sh <pmaports-directory>}
expected_revision=${PMAPORTS_REV:-1ce58c5ae1b7573c6471959c4ab406391eefb103}
package_dir="$pmaports/device/testing/linux-postmarketos-qcom-msm8916"

actual_revision=$(git -C "$pmaports" rev-parse HEAD)
if [ "$actual_revision" != "$expected_revision" ]; then
	echo "Expected pmaports $expected_revision, found $actual_revision" >&2
	exit 1
fi

test -f "$package_dir/APKBUILD"
test -f "$pmaports/device/testing/device-zhihe-generic/APKBUILD"
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

echo "Prepared pmaports linux-postmarketos-qcom-msm8916 for the 19-board image"
