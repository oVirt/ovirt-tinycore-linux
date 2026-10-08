#!/bin/sh
# The DHCP portion is now separated out, in order to not slow the boot down
# only to wait for slow network cards
. /etc/init.d/tc-functions

# This waits until all devices have registered
/sbin/udevadm settle --timeout=5

NETDEVICES="$(awk -F: '/eth.:|tr.:/{print $1}' /proc/net/dev 2>/dev/null)"
for DEVICE in $NETDEVICES; do
  trap 2 3 11
  /usr/sbin/dhcp-iface "$DEVICE"
  trap "" 2 3 11
done
