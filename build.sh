#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later

set -e

REPODIR=$(pwd)
if [ ! -d builddir ]; then
    mkdir builddir
fi

if [ ! -f ${REPODIR}/src/kernel/vmlinuz64 ]; then
    pushd ${REPODIR}/src/kernel/
    ./build.sh
    popd
fi

pushd builddir

mkdir {mnt,tmp}

wget http://www.tinycorelinux.net/13.x/x86_64/release/TinyCorePure64-13.1.iso

mount -o loop,ro TinyCorePure64-13.1.iso mnt
cp -av mnt/* tmp/
umount mnt

cp tmp/boot/corepure64.gz .

mkdir core.new
pushd core.new
zcat ../corepure64.gz | cpio -idmv
popd

wget http://www.tinycorelinux.net/13.x/x86_64/tcz/glib2.tcz
wget http://www.tinycorelinux.net/13.x/x86_64/tcz/ipv6-netfilter-5.15.10-tinycore64.tcz
wget http://www.tinycorelinux.net/13.x/x86_64/tcz/ipv6-netfilter-5.15.10-tinycore64.tcz.md5.txt
wget http://www.tinycorelinux.net/13.x/x86_64/tcz/qemu.tcz
wget http://www.tinycorelinux.net/13.x/x86_64/tcz/udev-lib.tcz

cp -av "${REPODIR}/sha256sums" .
sha256sum -c sha256sums

if [ ! -d tmp/cdeCLI/optional ]; then
    mkdir -p tmp/cdeCLI/optional/
fi

if [ ! -f ${REPODIR}/pkgs/ovirt-acpid/ovirt-acpid.tcz ]; then
    pushd ${REPODIR}/pkgs/ovirt-acpid/
    ./build.sh
    popd
fi

if [ ! -f ${REPODIR}/pkgs/ovirt-acpid/ovirt-acpid.tcz.md5.txt ]; then
    pushd ${REPODIR}/pkgs/ovirt-acpid/
    md5sum ovirt-acpid.tcz > ovirt-acpid.tcz.md5.txt
    popd
fi

cp -av ${REPODIR}/pkgs/ovirt-acpid/ovirt-acpid.tcz* tmp/cde/optional/
echo ovirt-acpid.tcz >> tmp/cde/onboot.lst
echo ovirt-acpid.tcz >> tmp/cde/onboot.CLI.lst
echo ovirt-acpid.tcz >> tmp/cde/copy2fs.lst

cp -avl tmp/cde/optional/ovirt-acpid.tcz* tmp/cdeCLI/optional/
echo ovirt-acpid.tcz >> tmp/cdeCLI/onboot.lst

mount glib2.tcz mnt
cp -av mnt/usr/local/lib/libglib-2.0.so* core.new/usr/local/lib/
cp -av mnt/usr/local/lib/libgthread-2.0.so* core.new/usr/local/lib/
umount mnt

cp -av ipv6-netfilter-5.15.10-tinycore64.tcz* tmp/cde/optional/
echo ipv6-netfilter-5.15.10-tinycore64.tcz >> tmp/cde/onboot.lst
echo ipv6-netfilter-5.15.10-tinycore64.tcz >> tmp/cde/onboot.CLI.lst
echo ipv6-netfilter-5.15.10-tinycore64.tcz >> tmp/cde/copy2fs.lst

cp -avl tmp/cde/optional/ipv6-netfilter-5.15.10-tinycore64.tcz* tmp/cdeCLI/optional/
echo ipv6-netfilter-5.15.10-tinycore64.tcz >> tmp/cdeCLI/onboot.lst

mount qemu.tcz mnt
cp -av mnt/usr/local/bin/qemu-ga core.new/usr/bin/
umount mnt

mount udev-lib.tcz mnt
cp -av mnt/usr/local/lib/* core.new/usr/local/lib/
umount mnt

cp -av ${REPODIR}/src/core/etc/* core.new/etc/

pushd core.new
find . | cpio -ov -H newc | gzip -9 > ../corepure64.gz
popd

cp corepure64.gz tmp/boot/

cp -v ${REPODIR}/src/kernel/vmlinuz64 tmp/boot/

cp -av ${REPODIR}/src/isolinux/* tmp/boot/isolinux/

mkisofs -J -T -U -joliet-long -A "oVirtTinyCore64" -V "oVirtTinyCore64" -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -R -graft-points -o oVirtTinyCore64-13.7.iso tmp/

popd
