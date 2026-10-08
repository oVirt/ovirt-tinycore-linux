#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later

set -eao pipefail
. ./version

if [ ! -f "qcowbuilddir/oVirtTinyCore64-${VERSION}.qcow2" ]; then
  echo -e  "\033[0;31mPlease run './build.sh' first\033[0m" >&2
  exit 1
fi

if ! command -v gocr &> /dev/null
then
  echo -e  "\033[0;31mPlease install gocr to run this test.\033[0m" >&2
  exit 1
fi

if ! command -v qemu-system-x86_64 &> /dev/null
then
  echo -e "\033[0;31mPlease install qemu to run this test.\033[0m" >&2
  exit 1
fi

if ! command -v nc &> /dev/null
then
  echo -e "\033[0;31mPlease install netcat to run this test.\033[0m" >&2
  exit 1
fi

if ! command -v convert &> /dev/null
then
  echo -e "\033[0;31mPlease install imagemagick to run this test.\033[0m" >&2
  exit 1
fi

# The image has to boot under UEFI too, so the test needs an OVMF firmware.
# The file names differ by distro (-, _4M, .4m) and CODE/VARS must be one pair.
OVMF_CODE=""
OVMF_VARS=""
for dir in /usr/share/OVMF /usr/share/ovmf /usr/share/edk2/x64; do
  for suffix in "" _4M .4m; do
    if [ -f "${dir}/OVMF_CODE${suffix}.fd" ] && [ -f "${dir}/OVMF_VARS${suffix}.fd" ]; then
      OVMF_CODE="${dir}/OVMF_CODE${suffix}.fd"
      OVMF_VARS="${dir}/OVMF_VARS${suffix}.fd"
      break 2
    fi
  done
done
if [ -z "${OVMF_CODE}" ]; then
  echo -e "\033[0;31mPlease install ovmf to run this test.\033[0m" >&2
  exit 1
fi


function group {
  if [ -n "${GITHUB_ACTIONS}" ]; then
    echo -n "::group::"
  fi
  echo -e $1
}

function endgroup {
  if [ -n "${GITHUB_ACTIONS}" ]; then
    echo "::endgroup::"
  fi
}

function log {
  echo -e "\033[0;33m$*\033[0m"
}

function error {
  echo -e "\033[0;31m$*\033[0m"
}

function success {
  MSG=$1
  echo -e "\033[0;32m${MSG}\033[0m"
}



log "⚙️ Starting VMs with image (legacy BIOS and UEFI)..."

QCOW2=$(pwd)/qcowbuilddir/oVirtTinyCore64-${VERSION}.qcow2
# QEMU locks the image for writing, so give each VM its own copy.
cp "${QCOW2}" /tmp/vm-legacy-bios.qcow2
cp "${QCOW2}" /tmp/vm-uefi.qcow2

(
  qemu-system-x86_64 \
    -nographic \
    -serial mon:stdio \
    -m 512 \
    -drive file=/tmp/vm-legacy-bios.qcow2,format=qcow2 \
    -monitor telnet::2000,server,nowait >/tmp/qemu-legacy-bios.log
) &

# OVMF needs a writable variable store, so boot from a copy of the template.
cp "${OVMF_VARS}" /tmp/ovmf-vars.fd
(
  qemu-system-x86_64 \
    -machine q35 \
    -nographic \
    -serial mon:stdio \
    -m 512 \
    -drive if=pflash,format=raw,readonly=on,file=${OVMF_CODE} \
    -drive if=pflash,format=raw,file=/tmp/ovmf-vars.fd \
    -drive file=/tmp/vm-uefi.qcow2,format=qcow2 \
    -monitor telnet::2001,server,nowait >/tmp/qemu-uefi.log
) &

sleep 240
echo 'screendump /tmp/screendump-legacy-bios.ppm
system_powerdown' | nc localhost 2000 >/dev/null
echo 'screendump /tmp/screendump-uefi.ppm
system_powerdown' | nc localhost 2001 >/dev/null
sleep 10

for VM in legacy-bios uefi; do
  echo -e "\033[2m"
  cat /tmp/qemu-${VM}.log
  echo -e "\033[0m"
  convert /tmp/screendump-${VM}.ppm oVirtTinyCore-${VM}.png
done

log "⚙️ Performing OCR and evaluating results..."
RET=0
for VM in legacy-bios uefi; do
  if [ $(gocr -m 4 /tmp/screendump-${VM}.ppm 2>/dev/null | grep 'Customized by oVirt' | wc -l) -ne 1 ]; then
    error "❌ Test failed: the ${VM} virtual machine did not print \"Customized by oVirt\" to the output when run."
    RET=1
  fi
done
[ ${RET} -eq 0 ] || exit ${RET}

success "✅ Test successful."
