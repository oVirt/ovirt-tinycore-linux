#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later

set -e
export KBUILD_BUILD_USER=lveyde
export KBUILD_BUILD_HOST=RedHat.Israel

sudo apt install -y libelf-dev

wget http://www.tinycorelinux.net/13.x/x86_64/release/src/kernel/linux-5.15.10-patched.txz

sha256sum -c sha256sums

tar xvf linux-5.15.10-patched.txz

cp config-5.15.10-tinycore64-patched linux-5.15.10/.config

pushd linux-5.15.10
make bzImage -j2
cp -v arch/x86/boot/bzImage ../vmlinuz64
popd

