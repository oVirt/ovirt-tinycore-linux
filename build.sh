#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later

set -e

. ./version

SBIN_APPLETS="ip ipaddr iplink ipneigh iproute iprule iptunnel"
USR_BIN_APPLETS="udhcpc6"

REPODIR=$(pwd)
if [ ! -d builddir ]; then
    mkdir builddir
fi

if [ ! -f ${REPODIR}/src/kernel/vmlinuz64 ]; then
    pushd ${REPODIR}/src/kernel/
    ./build.sh
    popd
fi

if [ ! -f ${REPODIR}/src/busybox/busybox.tar.gz ]; then
    pushd ${REPODIR}/src/busybox/
    ./build.sh
    tar czvf busybox.tar.gz pkg/
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
wget http://www.tinycorelinux.net/13.x/x86_64/tcz/pcre.tcz
wget http://www.tinycorelinux.net/13.x/x86_64/tcz/pcre.tcz.md5.txt
wget http://www.tinycorelinux.net/13.x/x86_64/tcz/qemu.tcz
wget http://www.tinycorelinux.net/13.x/x86_64/tcz/udev-lib.tcz
wget http://www.tinycorelinux.net/13.x/x86_64/tcz/openssh.tcz
wget http://www.tinycorelinux.net/13.x/x86_64/tcz/openssl-1.1.1.tcz

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

cp -av pcre.tcz* tmp/cde/optional/
echo pcre.tcz >> tmp/cde/onboot.lst
echo pcre.tcz >> tmp/cde/onboot.CLI.lst
echo pcre.tcz >> tmp/cde/copy2fs.lst

cp -avl tmp/cde/optional/pcre.tcz* tmp/cdeCLI/optional/
echo pcre.tcz >> tmp/cdeCLI/onboot.lst

mount qemu.tcz mnt
cp -av mnt/usr/local/bin/qemu-ga core.new/usr/bin/
umount mnt

mount udev-lib.tcz mnt
cp -av mnt/usr/local/lib/* core.new/usr/local/lib/
umount mnt

mount openssh.tcz mnt
cp -av mnt/usr core.new/
umount mnt

mount openssl-1.1.1.tcz mnt
cp -av mnt/usr core.new/
umount mnt

cp core.new/usr/local/etc/ssh/sshd_config.orig core.new/usr/local/etc/ssh/sshd_config
mkdir core.new/var/lib/sshd
chmod 755 core.new/var/lib/sshd

cp -av ${REPODIR}/src/core/etc/* core.new/etc/
sed -i "s/OVTC_VERSION/${VERSION}/g" core.new/etc/os-release

cp -av ${REPODIR}/src/core/usr/share/udhcpc/* core.new/usr/share/udhcpc/

cp -av ${REPODIR}/src/busybox/bin/busybox core.new/bin/

pushd core.new/sbin
for applet in ${SBIN_APPLETS}
do
  ln -s ../bin/busybox ${applet}
done
popd

pushd core.new/usr/bin
for applet in ${USR_BIN_APPLETS}
do
  ln -s ../../bin/busybox ${applet}
done
popd

pushd core.new
find . | cpio -ov -H newc | gzip -9 > ../corepure64.gz
popd

cp corepure64.gz tmp/boot/

cp -v ${REPODIR}/src/kernel/vmlinuz64 tmp/boot/

cp -av ${REPODIR}/src/isolinux/* tmp/boot/isolinux/
sed -i "s/OVTC_VERSION/${VERSION}/g" tmp/boot/isolinux/boot.msg

mkisofs -U -J -joliet-long -A "oVirtTinyCore64" -V "oVirtTinyCore64"\
 -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat\
 -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot\
 -R -graft-points -e EFI/BOOT/efiboot.img\
 -o oVirtTinyCore64-${VERSION}.iso\
 tmp/

popd

cat > version.auto.pkrvars.hcl << EOF
version = "${VERSION}"
EOF
