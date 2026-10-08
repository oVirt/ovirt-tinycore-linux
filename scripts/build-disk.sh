#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Deterministic disk assembly for the oVirt TinyCore Linux test image:
# scripted losetup+mount assembly. Must run as ROOT inside a container that has:
#   losetup, mkfs.ext4, extlinux, mkfs.vfat, grub-mkstandalone, sfdisk, qemu-img (optional)
# e.g. the 'tc-build' ubuntu 22.04 container used by build.sh.
#
# Produces a GPT disk with:
#   partition 1: EFI System Partition (FAT)  - grub2-efi standalone loader
#   partition 2: root ext4 (/boot/vmlinuz64, /boot/corepure64.gz, /tce)
# The image boots BOTH legacy BIOS (SeaBIOS + extlinux/gptmbr) and UEFI
# (OVMF + grub) on q35 and i440fx machine types.

set -eo pipefail

# Run from the repo checkout (same layout as build.sh: builddir/tmp/...)
cd "$(dirname "$0")/.."
REPODIR=$(pwd)
. ./version

# Fixed filesystem UUID so extlinux.conf / grub.cfg / waitusb stay stable.
FSUUID=e6ae407a-390f-4e4c-9338-76d2905d8c57
# Boot password baked into the kernel cmdline (plaintext there, acceptable
# for a test image); overridable via the PASSWORD environment variable.
PASSWORD=${PASSWORD:-oVirtRocks}
IMG=${1:-${REPODIR}/builddir/disk.raw}
ESP_SECTORS=40960        # 20 MiB ESP
ROOT_START=2048          # first usable sector, 1MiB alignment
SECTOR_SIZE=512          # bytes
TOTAL_SIZE=$((96 * 1024 * 1024))  # 96 MiB image
GPT_RESERVED=33          # GPT backup: header + 32 partition-entry sectors

SRC=${REPODIR}/builddir/tmp
[ -d "${SRC}/boot" ] || { echo "run build.sh first (${SRC} missing)" >&2; exit 1; }

command -v losetup >/dev/null || { echo "needs losetup (run as root in container)" >&2; exit 1; }
for t in mkfs.ext4 extlinux mkfs.vfat grub-mkstandalone sfdisk; do
    command -v $t >/dev/null || { echo "missing tool: $t" >&2; exit 1; }
done
GPTMBR=/usr/lib/EXTLINUX/gptmbr.bin
[ -f "${GPTMBR}" ] || { echo "missing ${GPTMBR} (from the extlinux package)" >&2; exit 1; }

rm -f "${IMG}"
# 96M total: 20M ESP + ~75M root; root content is currently ~23M (CLI
# extension set only), leaving ample room for additional extensions before
# TOTAL_SIZE needs resizing.
truncate -s "${TOTAL_SIZE}" "${IMG}"

# --- GPT partition table (fixed disk UUID for reproducibility) ---------------
sfdisk --quiet "${IMG}" <<PART
label: gpt
label-id: 6a4c1d0e-1111-4e4c-9338-000000000001
unit: sectors
first-lba: ${ROOT_START}

name=EFI, start=${ROOT_START}, size=${ESP_SECTORS}, type=uefi, uuid=11111111-2222-4333-8444-555555555551
name=root, start=$((ROOT_START + ESP_SECTORS)), size=$((TOTAL_SIZE / SECTOR_SIZE - ROOT_START - ESP_SECTORS - GPT_RESERVED)), type=linux, uuid=11111111-2222-4333-8444-555555555552, attrs=LegacyBIOSBootable
PART

# MBR boot code: gptmbr scans GPT for the LegacyBIOSBootable partition
# and chainloads its extlinux VBR (SeaBIOS path).
dd if="${GPTMBR}" of="${IMG}" bs=440 count=1 conv=notrunc

# Private mountpoints (never mount over the host's /mnt) plus an EXIT
# cleanup that is safe at any failure point under 'set -e'.
ROOT_MNT=$(mktemp -d)
ESP_MNT=$(mktemp -d)
EMBED_CFG=$(mktemp)
LOOP=""
cleanup() {
    umount "${ESP_MNT}" 2>/dev/null || true
    umount "${ROOT_MNT}" 2>/dev/null || true
    # only rm the dirs if they are no longer mountpoints
    mountpoint -q "${ESP_MNT}" 2>/dev/null || rm -rf "${ESP_MNT}"
    mountpoint -q "${ROOT_MNT}" 2>/dev/null || rm -rf "${ROOT_MNT}"
    rm -f "${EMBED_CFG}"
    [ -n "${LOOP}" ] && losetup -d "${LOOP}" 2>/dev/null || true
}
trap cleanup EXIT

LOOP=$(losetup -f --show -P "${IMG}")
partx -u "${LOOP}" 2>/dev/null || true

# containers often run without udev: create missing partition device nodes
ensure_dev() {
    local dev="/dev/$1"
    rm -f "$dev"
    read -r MA MI <<< "$(awk -v n="$1" '$4==n {print $1, $2}' /proc/partitions)"
    if [ -n "$MA" ]; then
        mknod "$dev" b "$MA" "$MI" || { echo "cannot create $dev" >&2; exit 1; }
    fi
}
ensure_dev "$(basename ${LOOP})p1"
ensure_dev "$(basename ${LOOP})p2"

# --- partition 2: root ext4 ---------------------------------------------------
mkfs.ext4 -q -F -U "${FSUUID}" -L oVirtTinyCore "${LOOP}p2"
mount "${LOOP}p2" "${ROOT_MNT}"

mkdir -p "${ROOT_MNT}/boot" "${ROOT_MNT}/tce"
cp -a "${SRC}/boot/vmlinuz64" "${SRC}/boot/corepure64.gz" "${ROOT_MNT}/boot/"
cp -a "${SRC}/cdeCLI/." "${ROOT_MNT}/tce/"

# The boot loads /tce/onboot.lst, so every extension it names must be present,
# and none may sit a level deeper: a nested copy is never scanned and ships
# silently as dead weight.
while read -r ext; do
    [ -z "${ext}" ] && continue
    [ -f "${ROOT_MNT}/tce/optional/${ext}" ] || { echo "missing extension in image: ${ext}" >&2; exit 1; }
done < "${ROOT_MNT}/tce/onboot.lst"
[ -z "$(find "${ROOT_MNT}/tce/optional" -mindepth 1 -type d)" ] || { echo "extensions nested too deep under /tce/optional" >&2; exit 1; }

# legacy-BIOS loader (SeaBIOS): extlinux in the root partition VBR
mkdir -p "${ROOT_MNT}/boot/extlinux"
cat > "${ROOT_MNT}/boot/extlinux/extlinux.conf" <<CFG
DEFAULT tc
LABEL tc
KERNEL /boot/vmlinuz64
INITRD /boot/corepure64.gz
APPEND quiet console=ttyS0,115200 console=tty0 password=${PASSWORD} waitusb=5:UUID="${FSUUID}" tce=UUID="${FSUUID}"
CFG
extlinux --install "${ROOT_MNT}/boot/extlinux"

# --- partition 1: EFI System Partition (OVMF/UEFI boot) ----------------------
# Fixed volume id for byte-stable ESP content
mkfs.vfat -n EFI -i 6a4c1d0e "${LOOP}p1" >/dev/null
cat > "${EMBED_CFG}" <<GCFG
set default=0
set timeout=1
menuentry "oVirt TinyCore Linux" {
    search --no-floppy --fs-uuid --set=root ${FSUUID}
    linux /boot/vmlinuz64 quiet console=ttyS0,115200 console=tty0 password=${PASSWORD} waitusb=5:UUID=${FSUUID} tce=UUID=${FSUUID}
    initrd /boot/corepure64.gz
}
GCFG

mount "${LOOP}p1" "${ESP_MNT}"
mkdir -p "${ESP_MNT}/EFI/BOOT"
# Standalone grub2-efi image with the kernel options baked in; reads
# kernel/initrd from the ext4 root partition. BOOTX64.EFI is the
# removable-media path OVMF falls back to when no NVRAM entry exists.
grub-mkstandalone -O x86_64-efi \
    -o "${ESP_MNT}/EFI/BOOT/BOOTX64.EFI" \
    --modules="ext2 part_gpt search search_fs_uuid linux normal configfile echo test" \
    --locales= --themes= --fonts= \
    "boot/grub/grub.cfg=${EMBED_CFG}"

sync
umount "${ESP_MNT}"
umount "${ROOT_MNT}"

# --- protect partitions / finalize -------------------------------------------
sync
losetup -d "${LOOP}"
LOOP=""
# EXIT trap cleanup still runs and is a no-op now

# convert to qcow2 for oVirt/OST consumption if qemu-img is available
OUTDIR=${REPODIR}/qcowbuilddir
if command -v qemu-img >/dev/null; then
    mkdir -p "${OUTDIR}"
    qemu-img convert -f raw -O qcow2 -o compat=1.1 "${IMG}" \
        "${OUTDIR}/oVirtTinyCore64-${VERSION}.qcow2"
    echo "qcow2: ${OUTDIR}/oVirtTinyCore64-${VERSION}.qcow2"
else
    echo "qemu-img not found; raw image only: ${IMG}"
fi
