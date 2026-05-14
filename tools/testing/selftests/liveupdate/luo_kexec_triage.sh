#!/bin/sh
# SPDX-License-Identifier: GPL-2.0
set -eu

# Collect pre-kexec LUO/KHO artifacts and optionally trigger kexec.
#
# Usage examples:
#   sudo SCENARIO=lu_on_kho_on_no_access ./luo_kexec_triage.sh
#   sudo SCENARIO=lu_on_kho_on_open_only ACCESS_LIVEUPDATE=open ./luo_kexec_triage.sh
#   sudo RUN_KEXEC=1 KEXEC_APPEND="loglevel=8 initcall_debug" ./luo_kexec_triage.sh
#
# Environment:
#   SCENARIO         free-form label (default: unknown)
#   OUT_DIR          output directory (default: /tmp/luo-kexec-triage-<ts>)
#   ACCESS_LIVEUPDATE   none|open (default: none)
#   RUN_KEXEC        0|1 (default: 0)
#   KERNEL           target kernel image for kexec (default: /boot/bzImage)
#   INITRAMFS        target initramfs image (default: /boot/initramfs)
#   KEXEC_APPEND     extra kernel cmdline for next kernel

SCENARIO="${SCENARIO:-unknown}"
OUT_DIR="${OUT_DIR:-/tmp/luo-kexec-triage-$(date +%Y%m%d-%H%M%S)}"
ACCESS_LIVEUPDATE="${ACCESS_LIVEUPDATE:-none}"
RUN_KEXEC="${RUN_KEXEC:-0}"
KERNEL="${KERNEL:-/boot/bzImage}"
INITRAMFS="${INITRAMFS:-/boot/initramfs}"
KEXEC_APPEND="${KEXEC_APPEND:-}"

copy_path()
{
	src="$1"
	dst="$2"

	if [ -f "$src" ]; then
		cp "$src" "$dst"
	elif [ -d "$src" ]; then
		cp -a "$src" "$dst"
	fi
}

mkdir -p "$OUT_DIR"
echo "$SCENARIO" >"$OUT_DIR/scenario.txt"
uname -a >"$OUT_DIR/uname.txt"
cat /proc/cmdline >"$OUT_DIR/proc-cmdline.txt"
date -Ins >"$OUT_DIR/collect-start.txt"

if [ ! -d /sys/kernel/debug ]; then
	echo "debugfs mountpoint missing: /sys/kernel/debug" >&2
fi

if [ ! -d /sys/kernel/debug/kho ]; then
	mount -t debugfs debugfs /sys/kernel/debug >/dev/null 2>&1 || true
fi

mkdir -p "$OUT_DIR/kho-out" "$OUT_DIR/kho-in"
copy_path /sys/kernel/debug/kho/out/fdt "$OUT_DIR/kho-out/fdt"
copy_path /sys/kernel/debug/kho/out/scratch_len "$OUT_DIR/kho-out/scratch_len"
copy_path /sys/kernel/debug/kho/out/scratch_phys "$OUT_DIR/kho-out/scratch_phys"
copy_path /sys/kernel/debug/kho/out/sub_fdts "$OUT_DIR/kho-out/sub_fdts"
copy_path /sys/kernel/debug/kho/in/fdt "$OUT_DIR/kho-in/fdt"
copy_path /sys/kernel/debug/kho/in/sub_fdts "$OUT_DIR/kho-in/sub_fdts"

if [ "$ACCESS_LIVEUPDATE" = "open" ]; then
	if [ -e /dev/liveupdate ]; then
		exec 9<>/dev/liveupdate
		exec 9>&-
		echo "opened and closed /dev/liveupdate" >"$OUT_DIR/liveupdate-access.txt"
	else
		echo "/dev/liveupdate does not exist" >"$OUT_DIR/liveupdate-access.txt"
	fi
fi

dmesg >"$OUT_DIR/dmesg-before-kexec.txt" 2>/dev/null || true

if [ "$RUN_KEXEC" != "1" ]; then
	echo "Artifacts collected at: $OUT_DIR"
	echo "RUN_KEXEC=0, skipping kexec execution."
	exit 0
fi

if [ ! -f "$KERNEL" ]; then
	echo "KERNEL image not found: $KERNEL" >&2
	exit 1
fi

set -- -l -s --reuse-cmdline "$KERNEL"
if [ -f "$INITRAMFS" ]; then
	set -- "$@" --initrd="$INITRAMFS"
fi
if [ -n "$KEXEC_APPEND" ]; then
	set -- "$@" --append="$KEXEC_APPEND"
fi

echo "kexec $*" >"$OUT_DIR/kexec-command.txt"
kexec "$@"
sync
kexec -e
