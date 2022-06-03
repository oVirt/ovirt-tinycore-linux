#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later

set -eao pipefail
. ./version

if [ ! -f "qcowbuilddir/oVirtTinyCore64-${VERSION}.qcow2" ]; then
  echo -e  "\033[0;31mPlease run 'packer build .' first\033[0m" >&2
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



log "⚙️ Starting VM with image..."

(
  qemu-system-x86_64 \
    -nographic \
    -serial mon:stdio \
    -drive file=$(pwd)/output/oVirtTinyCore64-${VERSION}.qcow2,format=qcow2 \
    -monitor telnet::2000,server,nowait >/tmp/qemu.log
) &

sleep 240
echo 'screendump /tmp/screendump.ppm
system_powerdown' | nc localhost 2000 >/dev/null
sleep 10
echo -e "\033[2m"
cat /tmp/qemu.log
echo -e "\033[0m"
convert /tmp/screendump.ppm oVirtTinyCore.png

log "⚙️ Performing OCR and evaluating results..."
if [ $(gocr -m 4 /tmp/screendump.ppm 2>/dev/null | grep 'Customized for oVirt by Lev Veyde' | wc -l) -ne 1 ]; then
  error "❌ Test failed: the virtual machine did not print \"Customized for oVirt by Lev Veyde\" to the output when run."
  exit 1
fi

success "✅ Test successful."
