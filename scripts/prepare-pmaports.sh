#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
pmaports=${1:?Usage: prepare-pmaports.sh <pmaports-directory>}
expected_revision=${PMAPORTS_REV:-6fb3a1e5eb21c809891645a2ba5ae11fa788e032}
package_dir="$pmaports/device/testing/linux-postmarketos-qcom-msm8916"

actual_revision=$(git -C "$pmaports" rev-parse HEAD)
if [ "$actual_revision" != "$expected_revision" ]; then
	echo "Expected pmaports $expected_revision, found $actual_revision" >&2
	exit 1
fi

test -f "$package_dir/APKBUILD"
patch --batch --forward -d "$pmaports" -p1 < "$repo_root/patches/pmaports-linux-multiboard.patch"
"$repo_root/scripts/stage-device-trees.sh" "$package_dir"

echo "Prepared pmaports linux-postmarketos-qcom-msm8916 for the 19-board image"
