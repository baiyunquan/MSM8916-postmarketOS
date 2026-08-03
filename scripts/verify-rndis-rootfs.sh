#!/usr/bin/env bash
set -euo pipefail

root_image=${1:?Usage: verify-rndis-rootfs.sh <postmarketOS-root-image>}
mount_dir=$(mktemp -d)

fail() {
	echo "ERROR: $*" >&2
	if mountpoint -q "$mount_dir"; then
		echo "RNDIS-related files in the mounted root image:" >&2
		find "$mount_dir/usr/sbin" "$mount_dir/usr/lib/systemd" \
			"$mount_dir/etc/systemd" "$mount_dir/etc/NetworkManager" \
			"$mount_dir/etc/udev" -iname '*rndis*' -ls 2>/dev/null >&2 || true
	fi
	exit 1
}

cleanup() {
	if mountpoint -q "$mount_dir"; then
		umount "$mount_dir"
	fi
	rmdir "$mount_dir"
}
trap cleanup EXIT

if [ "$(id -u)" -ne 0 ]; then
	echo "verify-rndis-rootfs.sh must run as root (use sudo)." >&2
	exit 1
fi
if [ ! -s "$root_image" ]; then
	echo "Root image is missing or empty: $root_image" >&2
	exit 1
fi

require_file() {
	[ -f "$1" ] || fail "missing regular file: $1"
}

require_executable() {
	[ -x "$1" ] || fail "missing executable file: $1"
}

require_mode() {
	local path=$1
	local expected=$2
	local actual
	actual=$(stat -c '%a' "$path") || fail "cannot read mode for: $path"
	[ "$actual" = "$expected" ] || fail "unexpected mode for $path: expected $expected, got $actual"
}

require_link_target() {
	local path=$1
	local expected=$2
	local actual
	[ -L "$path" ] || fail "missing systemd enablement symlink: $path"
	actual=$(readlink "$path")
	[ "$actual" = "$expected" ] \
		|| fail "unexpected systemd unit target for $path: expected $expected, got $actual"
}

require_text() {
	local text=$1
	local path=$2
	grep -Fq "$text" "$path" || fail "missing required text '$text' in $path"
}

mount -o loop,ro "$root_image" "$mount_dir" || fail "cannot mount root image: $root_image"

gadget_script="$mount_dir/usr/sbin/usb-gadget-rndis"
unit_file="$mount_dir/usr/lib/systemd/system/usb-gadget-rndis.service"
preset_file="$mount_dir/usr/lib/systemd/system-preset/90-msm8916-rndis.preset"
connection_file="$mount_dir/etc/NetworkManager/system-connections/usb-gadget-rndis.nmconnection"
nm_config="$mount_dir/etc/NetworkManager/conf.d/90-msm8916-rndis.conf"
udev_rule="$mount_dir/etc/udev/rules.d/99-msm8916-rndis.rules"
unit_link="$mount_dir/etc/systemd/system/multi-user.target.wants/usb-gadget-rndis.service"

require_executable "$gadget_script"
require_file "$unit_file"
require_file "$preset_file"
require_file "$connection_file"
require_file "$nm_config"
require_file "$udev_rule"
require_mode "$connection_file" 600
require_link_target "$unit_link" /usr/lib/systemd/system/usb-gadget-rndis.service
require_text 'enable usb-gadget-rndis.service' "$preset_file"
require_text 'functions/rndis.usb0' "$gadget_script"
require_text '8a:b1:27:16:8e:a7' "$gadget_script"
require_text '2a:85:da:41:eb:f9' "$gadget_script"
require_text 'ENV{NM_UNMANAGED}="0"' "$udev_rule"
require_text 'managed=1' "$nm_config"
require_text 'match-device=interface-name:usb0' "$nm_config"
require_text 'ignore-carrier=1' "$nm_config"
require_text 'method=shared' "$connection_file"
require_text 'address1=192.168.5.1/24' "$connection_file"
require_text 'Wants=NetworkManager.service' "$unit_file"
require_text 'ExecStart=/usr/sbin/usb-gadget-rndis start' "$unit_file"

echo "Verified the systemd RNDIS gadget and NetworkManager shared profile in the root image"
