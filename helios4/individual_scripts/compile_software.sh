#!/bin/bash

source functions.sh

echo "Installing required libraries for cryptodev and cryptsetup compilation…" 2>&1 | tee $LOG
# uncomment source repositories and install required libraries
# this sed command is technically unsafe since it will uncomment repositories you may not want.
#sed -e "s/^# deb/deb/g" /etc/apt/sources.list
apt update && apt install -y build-essential uuid-dev libdevmapper-dev libpopt-dev pkg-config libgcrypt20-dev libblkid-dev libjson-c3 libjson-c-dev build-essential fakeroot devscripts debhelper linux-headers-next-mvebu git

# all the Helios4 kernels are built with the CESA module afaik
echo "Loading the Marvel CESA module and enabling it on boot…"  2>&1 | tee $LOG
modprobe marvell_cesa
echo "marvell_cesa" >> /etc/modules

echo "Downloading, compiling, and installing Cryptodev…" 2>&1 | tee $LOG
mkdir git
cd git
sudo -u $USER git clone https://github.com/cryptodev-linux/cryptodev-linux.git
cd cryptodev-linux/
make
make install
depmond -a #just in case
modprobe cryptodev
echo "cryptodev" >> /etc/modules
cd ..

# cryptsetup 2.x needed for LUKS2 support
# change the branch to the latest stable version
# v2.2.1 is the latest as of writing this
# LUKS2 gives us the ability to set the block size to 4096 instead of 512
echo "Downloading, compiling, and installing Cryptsetup 2…" 2>&1 | tee $LOG
sudo -u $USER git clone -b v2.2.1 https://gitlab.com/cryptsetup/cryptsetup.git
cd cryptsetup
./autogen.sh
./configure --prefix=/usr/local
make
make install
ldconfig
cd ../..
