#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later

set -eao pipefail

RET=0

if [ ! -f "qcowbuilddir/oVirtTinyCore-13.7.qcow2" ]; then
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

nohup qemu-system-x86_64 \
    -nographic \
    -drive file=$(pwd)/output/oVirtTinyCore-13.7.qcow2,format=qcow2 \
    -monitor telnet::2000,server,nowait >/tmp/qemu.log 2>/dev/null &

log 'Waiting for the VM to start...'
sleep 240

echo 'screendump /tmp/screendump.ppm' | nc localhost 2000 >/dev/null
sleep 1

echo -e "\033[2m"
cat /tmp/qemu.log
echo -e "\033[0m"
convert /tmp/screendump.ppm oVirtTinyCore.png

log "⚙️ Performing ACPI test..."

echo 'system_powerdown' | nc localhost 2000 >/dev/null
sleep 10

if [ -d /proc/$! ]; then
    error "❌ Test failed: the virtual machine didn't properly respond to shutdown command."
    echo 'Taking another screenshot...'
    echo 'screendump /tmp/screendump-failed_shutdown.ppm' | nc localhost 2000 >/dev/null &
    sleep 5
    echo 'Forcing VM poweroff...'
    echo 'quit' | nc localhost 2000 > /dev/null &
    convert /tmp/screendump-failed_shutdown.ppm oVirtTinyCore-failed_shutdown.png
    sleep 1
    RET=1
else
    success "✅ Test successful."
fi

log "⚙️ Performing OCR test..."
if [ $(gocr -m 4 /tmp/screendump.ppm 2>/dev/null | grep 'Customized for oVirt by Lev Veyde' | wc -l) -ne 1 ]; then
    error "❌ Test failed: the virtual machine did not print \"Customized for oVirt by Lev Veyde\" to the output when run."
    RET=1
else
    success "✅ Test successful."
fi

exit ${RET}
