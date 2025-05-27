#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later

set -e

REPODIR=$(pwd)

wget http://www.tinycorelinux.net/13.x/x86_64/release/src/busybox/busybox-1.27.1-wget-make-default-timeout-configurable.patch
wget http://www.tinycorelinux.net/13.x/x86_64/release/src/busybox/busybox-1.29.3_root_path.patch
wget http://www.tinycorelinux.net/13.x/x86_64/release/src/busybox/busybox-1.33.0_modprobe.patch
wget http://www.tinycorelinux.net/13.x/x86_64/release/src/busybox/busybox-1.33.0_skip-loop-control.patch
wget http://www.tinycorelinux.net/13.x/x86_64/release/src/busybox/busybox-1.33.0_tc_depmod.patch
wget http://www.tinycorelinux.net/13.x/x86_64/release/src/busybox/busybox-1.34.1.tar.bz2

sha256sum -c sha256sums

tar xvf busybox-1.34.1.tar.bz2
cd busybox-1.34.1

patch -Np1 -i ../busybox-1.27.1-wget-make-default-timeout-configurable.patch
patch -Np1 -i ../busybox-1.29.3_root_path.patch
patch -Np1 -i ../busybox-1.33.0_modprobe.patch
patch -Np1 -i ../busybox-1.33.0_skip-loop-control.patch
patch -Np0 -i ../busybox-1.33.0_tc_depmod.patch

cp -v ${REPODIR}/busybox-1.34.1_config_suid .config

make CC="gcc -flto -mtune=generic -Os -pipe" CXX="g++ -flto -mtune=generic -Os -pipe -fno-exceptions -fno-rtti" CFLAGS="-g -I/usr/include/tirpc" LDLIBS+="-lcrypt -lm -ltirpc"

mkdir -p ${REPODIR}/pkg
make CC="gcc -flto -mtune=generic -Os -pipe" CXX="g++ -flto -mtune=generic -Os -pipe -fno-exceptions -fno-rtti" CFLAGS="-g -I/usr/include/tirpc" LDLIBS+="-lcrypt -lm -ltirpc" CONFIG_PREFIX=${REPODIR}/pkg install

mv ${REPODIR}/pkg/bin/busybox ${REPODIR}/pkg/bin/busybox.suid
chmod u+s ${REPODIR}/pkg/bin/busybox.suid

cp -v ${REPODIR}/busybox-1.34.1_config_nosuid-patched .config
make CC="gcc -flto -mtune=generic -Os -pipe" CXX="g++ -flto -mtune=generic -Os -pipe -fno-exceptions -fno-rtti" CFLAGS="-g -I/usr/include/tirpc" LDLIBS+="-lcrypt -lm -ltirpc"
make CC="gcc -flto -mtune=generic -Os -pipe" CXX="g++ -flto -mtune=generic -Os -pipe -fno-exceptions -fno-rtti" CFLAGS="-g -I/usr/include/tirpc" LDLIBS+="-lcrypt -lm -ltirpc" CONFIG_PREFIX=${REPODIR}/pkg install
