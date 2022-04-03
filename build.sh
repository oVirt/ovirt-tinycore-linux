#!/bin/bash
set -e

REPODIR=$(pwd)
if [ ! -d builddir ]; then
    mkdir builddir
fi

pushd builddir

mkdir {mnt,tmp}

wget http://www.tinycorelinux.net/13.x/x86/release/TinyCore-13.0.iso

mount -o loop,ro TinyCore-13.0.iso mnt
cp -av mnt/* tmp/
umount mnt

cp tmp/boot/core.gz .

mkdir core.new
pushd core.new
zcat ../core.gz | cpio -idmv
popd

wget http://www.tinycorelinux.net/13.x/x86/tcz/glib2.tcz
wget http://www.tinycorelinux.net/13.x/x86/tcz/qemu.tcz
wget http://www.tinycorelinux.net/13.x/x86/tcz/udev-lib.tcz

cp -av "${REPODIR}/sha256sums" .
sha256sum -c sha256sums

mount glib2.tcz mnt
cp -av mnt/usr/local/lib/libglib-2.0.so* core.new/usr/local/lib/
cp -av mnt/usr/local/lib/libgthread-2.0.so* core.new/usr/local/lib/
umount mnt

mount qemu.tcz mnt
cp -av mnt/usr/local/bin/qemu-ga core.new/usr/bin/
umount mnt

mount udev-lib.tcz mnt
cp -av mnt/usr/local/lib/* core.new/usr/local/lib/
umount mnt

cp -av ${REPODIR}/src/core/etc/* core.new/etc/

pushd core.new
find . | cpio -ov -H newc | gzip -9 > ../core.gz
popd

cp core.gz tmp/boot/

cp -av ${REPODIR}/src/isolinux/* tmp/boot/isolinux/

mkisofs -J -T -U -joliet-long -A "oVirtTinyCore" -V "oVirtTinyCore" -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -R -graft-points -o oVirtTinyCore-13.3.iso tmp/

popd
