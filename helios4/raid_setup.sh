#!/bin/bash

# Helios4 md RAID6+luks2+btrfs setup script
# Use with caution.

LOG="./raid_setup.log"
CONTAINER="five-nines"
MDARRAY="md0"

echo "WARNING!!! This will wipe ALL /dev/sdX disks!!" 2>&1 | tee $LOG
read -p "Press CTRL+C to quit, or any other key to continue." -n1 -s

if [[ $EUID -ne 0 ]]; then
	echo -e "You need to run this script as root, or with sudo!\nExiting..."
	exit 1
fi

echo "A full log will be available in $LOG"  2>&1 | tee $LOG

# in armbian these are probably all installed by default but better safe than sorry
echo "Installing some necessary software.." 2>&1 | tee $LOG
apt update && apt install -y e2fsprogs mdadm pv smartmontools btrfs-tools hdparm

# writing zeros over all the disks
# this is to wipe them and to prepare for the badblocks test below
echo "Wiping all disks…" 2>&1 | tee $LOG
for Dev in /sys/block/sd* ; do
	[-e $Dev]
	&& pv -tpreb /dev/zero | dd of=/dev/${Dev##*/} bs=4096 conv=notrunc,noerror 2>&1 | tee $LOG
	&& sleep 2
done

# run badblocks to check the disk actually wrote all zeros
# if it didn't, the disk is probably bad
# then run a long online SMART test and list its results
echo "Running disk checks…" 2>&1 | tee $LOG
for Dev in /sys/block/sd* ; do
	[-e $Dev]
	&& badblocks -sv -t 0x00 /dev/${Dev##*/} 2>&1 | tee $LOG
	&& smartctl -t long -C /dev/${Dev##*/} 2>&1 | tee $LOG
	&& smartctl -H /dev/${Dev##*/} 2>&1 | tee $LOG
	&& smartctl -l selftest /dev/${Dev##*/} 2>&1 | tee $LOG
	&& sleep 2
done

# create optimally aligned GPT partitions
echo "Setting up partitions…" 2>&1 | tee $LOG
for Dev in /sys/block/sd* ; do
	[-e $Dev]
	&& parted /dev/${Dev##*/} mklabel gpt 2>&1 | tee $LOG
	&& parted -a optimal /dev/${Dev##*/} mkpart primary 0% 100% 2>&1 | tee $LOG
	&& sleep 2
done

echo "Assembling RAID array…" 2>&1 | tee $LOG
disks=()
for Dev in /sys/block/sd* ; do
	disks+=("/dev/${Dev##*/}")
done

# create an md RAID6
mdadm --create --verbose /dev/$MDARRAY --level=6 --raid-devices=${#disks[@]}  ${disks[*]} 2>&1 | tee $LOG

echo "Installing required libraries for cryptodev and cryptsetup compilation…" 2>&1 | tee $LOG
# uncomment source repositories and install required libraries
# this sed command is technically unsafe since it will uncomment repositories you may not want.
sed -e "s/^# deb/deb/g" /etc/apt/sources.list
apt update && apt install -y build-essential uuid-dev libdevmapper-dev libpopt-dev pkg-config libgcrypt-dev libblkid-dev build-essential fakeroot devscripts debhelper install linux-headers-next-mvebu git

# all the Helios4 kernels are built with the CESA module afaik
echo "Loading the Marvel CESA module and enabling it on boot…"  2>&1 | tee $LOG
modprobe marvell_cesa
echo "marvell_cesa" >> /etc/modules

echo "Downloading, compiling, and installing Cryptodev…" 2>&1 | tee $LOG
git clone https://github.com/cryptodev-linux/cryptodev-linux.git
cd cryptodev-linux/
make
make install
depmod -a
modprobe cryptodev
echo "cryptodev" >> /etc/modules
cd ..

# cryptsetup 2.x needed for LUKS2 support
# LUKS2 gives us the ability to set the block size to 4096 instead of 512
echo "Downloading, compiling, and installing Cryptsetup 2…" 2>&1 | tee $LOG
wget -q -O - https://gitlab.com/cryptsetup/cryptsetup/-/archive/master/cryptsetup-master.tar.gz | tar xvzf &
cd cryptsetup-master/
./configure --prefix=/usr/local
ldconfig
cd ..

# pause the scripte until the initial RAID sync completes
# writing any data to the disks will slow the sync down by a factor of 12-15X
# for referece, that's 120-150MB/s down to ~10MB/s(!)
# RAID1/5/6 has NEGLIGIBLE redundancy until the data parity blocks are written to disk during the initial sync
# at 10MB/s, on an array of 8TB disks, the initial sync could take literally months to complete
# hence why my script waits for the sync to complete!
spin='-\|/'
echo "Waiting for initial RAID sync to complete. This may take a while…" 2>&1 | tee $LOG
while [ -n "$(mdadm --detail /dev/$MDARRAY | grep -ioE 'State :.*resyncing')" ]; do
	i=$(( (i+1) %4 ))
	printf "\r${spin:$i:1}"
	sleep .1
done
echo "RAID sync complete!" 2>&1 | tee $LOG

# this cipher is needed to take advantage of the marvell CESA module
# the block size is set to 4096 to reduce the encryption IO by 4x, as the default blocksize is 512
# see this benchmarking thread on the armbian forum for more info:
# https://forum.armbian.com/topic/8486-helios4-cryptographic-engines-and-security-accelerator-cesa-benchmarking/
echo -e "Creating crypt container.\nEnter passkey when prompted…" 2>&1 | tee $LOG
cryptsetup -v -y -c aes-cbc-essiv:sha256 -s 256 --sector-size 4096 --type luks2 luksFormat /dev/$MDARRAY 2>&1 | tee $LOG

# make sure the crypt container is filled with all zeros before creating partition
# this essentially uses the encryption cipher to increase entropy by filling the disks with random data
# see the cryptsetup FAQ item 2.19 "How can I wipe a device with crypto-grade randomness?" for an explanation:
# https://gitlab.com/cryptsetup/cryptsetup/wikis/FrequentlyAskedQuestions#2-setup
echo -e "Opening crypt container and wiping it.\nAgain, enter passkey when prompted…" 2>&1 | tee $LOG
cryptsetup luksOpen /dev/$MDARRAY $CONTAINER
pv -tpreb /dev/zero | dd of=/dev/mapper/$CONTAINER bs=4096 conv=notrunc,noerror

# again, set the block size to 4096 to reduce IO (and match the LUKS container)
echo "Formatting crypt container as btrfs…" 2>&1 | tee $LOG
mkfs.btrfs -s 4096 -d single -L $CONTAINER /dev/mapper/$CONTAINER

echo "Mounting btrfs partition to /mnt/$CONTAINER" 2>&1 | tee $LOG
mkdir /mnt/$CONTAINER
mount /dev/mapper/$CONTAINER /mnt/$CONTAINER

echo  -e "All done!\nTo mount the crypt container just type the following in terminal as root:\ncryptsetup luksOpen /dev/$MDARRAY $CONTAINER\nmount /dev/mapper/$CONTAINER /mnt/$CONTAINER" 2>&1 | tee $LOG

# if using this filesystem for samba shares, it's recommended to use btrfs subvolumes for shared folders
# this will allow per-share snapshots, and using the "previous history" feature in Windows.

exit 0

