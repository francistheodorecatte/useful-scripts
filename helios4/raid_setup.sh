#!/bin/bash

# Helios4 md RAID6+luks2+btrfs setup script
# Use with caution.

LOG="./raid_setup.log"
CONTAINER="five-nines"
MDARRAY="md0"

# function to convert seconds to days, hours, minutes, seconds.
# useful for converting the difference in seconds from two unix epoch timestamps
# e.g. for timing how long a section of a script takes where normal timing commands won't work
function convert_time(){
	var=$1
	min=0
	hour=0
	day=0
	if ((var>59)); then
		((sec=var%60))
		((var=var/60))
		if ((var>59)); then
			((min=var%60))
			((var=var/60))
			if ((var>23)); then
				((hour=var%24))
				((var=var/24))
			else
				((hour=var))
			fi
		else
			((min=var))
		fi
	else
		((sec=var))
	fi
	echo "$day"d "$hour"h "$min"m "$sec"s
}

echo "Helios4 MDRAID6 + btrfs + LUKS2 setup script by Francis Theodore Catte" 2>&1 | tee $LOG
echo "This script is mostly automated, but will pause occasionally, and will need monitoring." 2>&1 | tee $LOG
echo "Reading the log carefully in another terminal before continuing at prompts like the one below is HIGHLY recommended!" 2>&1 | tee $LOG
read -p "Press CTRL+C to quit, or any other key to continue." -n1 -s

if [[ $EUID -ne 0 ]]; then
	echo -e "\nYou need to run this script as root, or with sudo!\nExiting..."
	exit 1
fi

echo "WARNING!!! This will wipe ALL /dev/sdX disks!!" 2>&1 | tee $LOG
echo "A full log will be available in $LOG"  2>&1 | tee $LOG

# in armbian these are probably all installed by default but better safe than sorry
echo "Installing some necessary software.." 2>&1 | tee $LOG
apt update && apt install -y e2fsprogs mdadm pv smartmontools btrfs-tools hdparm

# writing zeros over all the disks
# this is to wipe them and to prepare for the badblocks test below
echo -e "Wiping all disks…\nThis may take a very long time!" 2>&1 | tee $LOG
for Dev in /sys/block/sd* ; do
	timer='date +%s'
	[-e $Dev]
	&& pv -tpreb /dev/zero | dd of=/dev/${Dev##*/} bs=4096 conv=notrunc,noerror 2>&1 | tee $LOG
	&& sleep 2
	timer=('date +%s'-$timer)
	echo "Erasing /dev/${Dev##*/} took " convert_time($timer) 2>&1 | tee $LOG
done

# run badblocks to check the disk actually wrote all zeros
# if it didn't, the disk is probably bad
# then run a long online SMART test and list its results
echo -e "Running disk checks…\nThis may take a very long time!" 2>&1 | tee $LOG
for Dev in /sys/block/sd* ; do
	timer='date +%s'
	[-e $Dev]
	&& badblocks -sv -t 0x00 -o ./badblocks_${Dev##*/}.txt /dev/${Dev##*/} 2>&1 | tee $LOG
	&& smartctl -t long -C /dev/${Dev##*/} 2>&1 | tee $LOG
	&& smartctl -H /dev/${Dev##*/} 2>&1 | tee $LOG
	&& smartctl -l selftest /dev/${Dev##*/} 2>&1 | tee $LOG
	&& sleep 2
	timer=('date +%s'-$timer)
	echo "Checking /dev/${Dev##*/} took " convert_time($timer) 2>&1 | tee $LOG
done

echo -e "Disk checks finished\n Before continuing, read over the log located at $LOG for the badblocks and smartctl reports."
echo -e "Additionally, each disk will have a badblocks_{FOO}.txt in the script directory.\bIf they're empty, badblocks reported no bad sectors and can be ignored.\nIf they're NOT empty, trash that drive! That means the disk has run out of sector reallocation space and can no longer mask bad sectors itself.\nThis should be noted by a high reallocated sector count in the smartctl report for this drive."
read -p "Press CTRL+C to quit, or any other key to continue." -n1 -s

# note that you can techinically use the disk if badblocks reports bad sectors, and the disk reports a high reallocated sector count!
# but ONLY in the case if rerunning the badblocks command above for that disk consistently returns the same bad blocks, and no new ones are added.
# this usually means the bad sector count is relatively stable, and on a new drive might be from a non-serious defect that made it through QC.
# HOWEVER it is NOT recommended to do this! if it's a new drive, running out of sector reallocation space is grounds for a warranty return!!
# this is an important thing to remember: the 'redundant' in RAID only means disk redundancy; DO NOT CONFLATE THAT WITH DATA REDUNDANCY.
# defective disks can do much more insidious things than outright failing!

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
mdadm --create --verbose /dev/$MDARRAY --level=6 --raid-devices=${#disks[@]}  ${disks[*]} 2>&1 | tee $LOG && timer=date +"%s"
timer='date +%s'

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

# pause the script until the initial RAID sync completes
# writing any data to the disks will slow the sync down by a factor of 12-15X
# for referece, that's 120-150MB/s down to ~10MB/s(!)
# RAID1/5/6 has NEGLIGIBLE redundancy until the data parity blocks are written to disk during the initial sync
# at 10MB/s, on an array of 8TB disks, the initial sync could take literally months to complete
# hence why my script waits for the sync to complete!
spin='-\|/'
echo -e "Waiting for initial RAID sync to complete.\n This may take a long time!" 2>&1 | tee $LOG
while [ -n "$(mdadm --detail /dev/$MDARRAY | grep -ioE 'State :.*resyncing')" ]; do
	i=$(( (i+1) %4 ))
	printf "\r${spin:$i:1}"
	sleep .1
done

# get the number of seconds since the timer started and convert to days, hours, minutes, seconds.
timer=('date +%s'-$timer)
executiontime=convert_time($timer)
echo "RAID sync complete after $executiontime!" 2>&1 | tee $LOG

# make sure md array is started on boot
echo "Adding md array to mdadm.conf so it starts on boot." 2>&1 | tee $LOG
mdadm --detail --scan | tee -a /etc/mdadm/mdadm.conf
update-initramfs -u

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
timer='date +%s'
pv -tpreb /dev/zero | dd of=/dev/mapper/$CONTAINER bs=4096 conv=notrunc,noerror
timer=('date +%s'-$timer)
echo "Wiping crypt container took " convert_time($timer) 2>&1 | tee $LOG

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

