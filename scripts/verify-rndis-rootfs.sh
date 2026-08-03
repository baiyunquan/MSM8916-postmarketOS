#!/usr/bin/env bash
set -euo pipefail

root_image=${1:?Usage: verify-rndis-rootfs.sh <postmarketOS-root-image>}
mount_dir=$(mktemp -d)

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

mount -o loop,ro "$root_image" "$mount_dir"

test -x "$mount_dir/usr/sbin/usb-gadget-rndis"
test -x "$mount_dir/etc/init.d/usb-gadget-rndis"
test -f "$mount_dir/etc/NetworkManager/system-connections/usb-gadget-rndis.nmconnection"
test -f "$mount_dir/etc/NetworkManager/conf.d/90-msm8916-rndis.conf"
test -f "$mount_dir/etc/udev/rules.d/99-msm8916-rndis.rules"
test "$(stat -c '%a' "$mount_dir/etc/NetworkManager/system-connections/usb-gadget-rndis.nmconnection")" = 600
test -L "$mount_dir/etc/runlevels/default/usb-gadget-rndis"
runlevel_target=$(readlink "$mount_dir/etc/runlevels/default/usb-gadget-rndis")
case "$runlevel_target" in
	/etc/init.d/usb-gadget-rndis|../../init.d/usb-gadget-rndis) ;;
	*)
		echo "Unexpected OpenRC runlevel target: $runlevel_target" >&2
		exit 1
		;;
esac
grep -Fq 'functions/rndis.usb0' "$mount_dir/usr/sbin/usb-gadget-rndis"
grep -Fq '8a:b1:27:16:8e:a7' "$mount_dir/usr/sbin/usb-gadget-rndis"
grep -Fq '2a:85:da:41:eb:f9' "$mount_dir/usr/sbin/usb-gadget-rndis"
grep -Fq 'ENV{NM_UNMANAGED}="0"' \
	"$mount_dir/etc/udev/rules.d/99-msm8916-rndis.rules"
grep -Fq 'managed=1' "$mount_dir/etc/NetworkManager/conf.d/90-msm8916-rndis.conf"
grep -Fq 'match-device=interface-name:usb0' \
	"$mount_dir/etc/NetworkManager/conf.d/90-msm8916-rndis.conf"
grep -Fq 'ignore-carrier=1' \
	"$mount_dir/etc/NetworkManager/conf.d/90-msm8916-rndis.conf"
grep -Fq 'method=shared' \
	"$mount_dir/etc/NetworkManager/system-connections/usb-gadget-rndis.nmconnection"
grep -Fq 'address1=192.168.5.1/24' \
	"$mount_dir/etc/NetworkManager/system-connections/usb-gadget-rndis.nmconnection"

echo "Verified the OpenRC RNDIS gadget and NetworkManager shared profile in the root image"
