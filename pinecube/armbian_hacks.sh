#!/bin/bash

set -e

# bump up /run to 23M permanently to keep systemd from complaining/
# necessary for <256MB of RAM; default -10% creates an 11MB /run tmpfs with 128MB of RAM.
sed -i 's/${RUNSIZE:-10%}/23M/g' /usr/share/initramfs-tools/init

# temporarily bump up /run and run upgrade
mount -t tmpfs tmpfs /run -o remount,size=23M,nosuid,noexec,relatime,mode=755

apt update && apt upgrade -y

#update-initramfs -u 

#echo "initramfs.runsize=23M" >> /boot/armbianEnv.txt

# set the current MAC to stick between reboots
MAC=$(cat /sys/class/net/eth0/address)
echo "MAC: $MAC"

echo "ethaddr=$MAC" >> /boot/armbianEnv.txt

cat << EOF >> /etc/network/interfaces

auto eth0
iface eth0 inet dhcp
	hwaddress ether ${MAC}
EOF

reboot