#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later

set -e

PKGDIR=$(pwd)
if [ ! -d builddir ]; then
    mkdir builddir
else
    rm -rf builddir
    mkdir builddir
fi

pushd builddir

wget http://www.tinycorelinux.net/13.x/x86_64/tcz/acpid.tcz

cp -v "${PKGDIR}/src/acpid.tcz.md5.txt" .
md5sum -c acpid.tcz.md5.txt

unsquashfs acpid.tcz
rm squashfs-root/usr/local/tce.installed/acpid
cp -v "${PKGDIR}/src/ovirt-acpid" squashfs-root/usr/local/tce.installed/ovirt-acpid
mksquashfs squashfs-root ovirt-acpid.tcz -b 4k -no-xattrs
md5sum ovirt-acpid.tcz > ovirt-acpid.tcz.md5.txt

cp -av ovirt-acpid.tcz* ../

popd
