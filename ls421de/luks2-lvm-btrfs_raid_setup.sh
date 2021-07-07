#!/bin/bash

# Debian Buster on LS421DE btrfs RAID1 + LUKS2 setup script by Francis Theodore Catte, 2021.
# Based off of my older Helios4 script.
# I recommend plugging the NAS into a battery backup for the duration of this script, since it may take literally an entire week.
# Use with caution.

LOG='$(dirname "$0")/raid_setup.log' 
CONTAINER="SS13" 
USER=$(logname)
spin='-\|/'

# create log file as non-root user to avoid root permissions 
# this technique will be used later for running git clones 
sudo -u $USER touch $LOG 
echo "Debian Buster on LS421DE btrfs RAID1 + LUKS2 setup script by Francis Theodore Catte" 2>&1 | tee $LOG 
echo "Make sure you have all deb-src lines uncommented in /etc/apt/sources.list before continuing" | 2>&1 | tee $LOG 
echo "This script is mostly automated, but will pause occasionally, and will need monitoring." 2>&1 | tee $LOG 
echo "Reading the log carefully in another terminal before continuing at prompts like the one below is HIGHLY recommended!" 2>&1 | tee $LOG 
read -p "Press CTRL+C to quit, or any other key to continue." -n1 -s 

if [[ $EUID -ne 0 ]]; then 
	echo -e "\nYou need to run this script as root, or with sudo!\nExiting..." 
	exit 1 
fi

echo "WARNING!!! This will wipe ALL /dev/sdX disks!!" 2>&1 | tee $LOG 
echo "ONLY HAVE DISKS YOU WISH TO BE IN THE RAID PLUGGED IN!" 2>&1 | tee $LOG 
echo "A full log will be available in $LOG"  2>&1 | tee $LOG 
if ! [ dpkg-query -s e2fsprogs mdadm pv smartmontools btrfs-tools hdparm >/dev/null 2>&1 ]; then 
	echo "Installing some necessary software.." 2>&1 | tee $LOG 
	apt update && apt install -y \ 
	e2fsprogs \ 
	mdadm \ 
	pv \ 
	smartmontools \ 
	btrfs-tools \ 
	hdparm
fi 

# wipe disks
for Dev in /sys/block/sd* ; do
	echo -e "Preparing to wipe /dev/${Dev##*/} with zeroes..." 2>&1 | tee $LOG
	dd if=/dev/zero of=/dev/${Dev##*/} bs=512 conv=sync,noerror &
done

echo -e "Waiting for disk wipes to complete.\n This may take a long time!" 2>&1 | tee $LOG
while [ -n "$(ps -aux | grep '[d]d if=/dev/zero')" ]; do
	i=$(( (i+1) %4 ))
	printf "\r${spin:$i:1}"
	sleep .1
done
echo -e"Done!\n" 2>&1 | tee $LOG

# run badblocks 
for Dev in /sys/block/sd* ; do 
	echo -e "Checking /dev/${Dev##*/} for bad blocks..." 2>&1 | tee $LOG 
	badblocks -sv -p 1 -b 512 -t 0x00 -o ./badblocks_${Dev##*/}.txt /dev/${Dev##*/} 2>&1 | tee $LOG &
done

echo -e "Waiting for badblocks scans to complete.\n This may take a long time!" 2>&1 | tee $LOG
while [ -n "$(ps -aux | grep '[b]adblocks')" ]; do
	i=$(( (i+1) %4 ))
	printf "\r${spin:$i:1}"
	sleep .1
done
echo -e "Done!\n" 2>&1 | tee $LOG

# then run a short online SMART test and list its results 
echo "Now running SMART tests." 2>&1 | tee $LOG
for Dev in /sys/block/sd* ; do
	smartctl -t short -C /dev/${Dev##*/} 2>&1 | tee $LOG \ 
	&& sleep 121 \ 
	&& smartctl -H /dev/${Dev##*/} 2>&1 | tee $LOG \ 
	&& smartctl -l selftest /dev/${Dev##*/} 2>&1 | tee $LOG \ 
	&& sleep 2
done 

echo -e "\nDisk checks finished\n Before continuing, read over the log located at $LOG for the badblocks and smartctl reports." 
echo -e "Additionally, each disk will have a badblocks_{FOO}.txt in the script directory.\bIf they're empty, badblocks reported no bad sectors and can be ignored.\nIf they're NOT empty, trash that drive! That means the disk has run out of sector reallocation space and can no longer mask bad sectors itself.\nThis should be noted by a high reallocated sector count in the smartctl report for this drive." 
read -p "Press CTRL+C to quit, or any other key to continue." -n1 -s 

# create optimally aligned GPT partitions 
echo "Setting up partitions…" 2>&1 | tee $LOG 
for Dev in /sys/block/sd* ; do 
	parted -s /dev/${Dev##*/} mklabel gpt 2>&1 | tee $LOG \ 
	&& parted -a optimal -s /dev/${Dev##*/} mkpart primary 0% 100% 2>&1 | tee $LOG \ 
	&& sleep 2
done 

echo "Installing required libraries for cryptodev and cryptsetup compilation." 2>&1 | tee $LOG 
# uncomment source repositories and install required libraries 
# this sed command is technically unsafe since it will uncomment repositories you may not want. 
#sed -e "s/^# deb/deb/g" /etc/apt/sources.list 
if ! [ dpkg-query -s build-essential uuid-dev libdevmapper-dev libpopt-dev pkg-config libgcrypt20-dev libblkid-dev libjson-c3 libjson-c-dev build-essential fakeroot devscripts debhelper linux-headers-next-mvebu git >/dev/null 2>&1 ]; then 
	apt update && apt install -y \ 
	build-essential \ 
	uuid-dev \ 
	libdevmapper-dev \ 
	libpopt-dev \ 
	pkg-config \ 
	libgcrypt20-dev \ 
	libblkid-dev \ 
	libjson-c3 \ 
	libjson-c-dev \ 
	build-essential \ 
	fakeroot \ 
	devscripts \ 
	debhelper \ 
	linux-headers-next-mvebu \ #need to check what the actual linux headers package is in this case, since 'linux-headers-next-mvebu' is for Armbian.
	git
fi 

# hopefully the kernel is compiled with the CESA module lol
# or we're stuck with a default software cypher and way slower access speeds
if ! grep -q "marvell_cesa" /etc/modules; then 
	echo "Loading the Marvel CESA module and enabling it on boot."  2>&1 | tee $LOG 
	modprobe marvell_cesa 
	echo "marvell_cesa" >> /etc/modules 
fi 

if ! grep -q "cryptodev" /etc/modules; then 
	echo "Downloading, compiling, and installing Cryptodev." 2>&1 | tee $LOG 
	sudo -u $USER git clone https://github.com/cryptodev-linux/cryptodev-linux.git 
	cd cryptodev-linux/ 
	make 
	make install 
	depmod -a #just in case 
	modprobe cryptodev 
	echo "cryptodev" >> /etc/modules 
	cd .. 
	rm -r ./cryptodev
fi

# cryptsetup 2.x needed for LUKS2 support 
# change the branch to the latest stable version 
# v2.3.6 is the latest as of writing this 
if command -v cryptsetup; then 
	dpkg --compare-versions "2" "ge" "$(cryptsetup --version | cut -d' ' -f2)" 
	if [ $? -eq "0" ]; then
		echo "Cryptsetup 2+ already installed" 2>&1 | tee $LOG 
	fi 
else 
	echo "Downloading, compiling, and installing Cryptsetup 2." 2>&1 | tee $LOG 
	sudo -u $USER git clone -b v2.3.6 https://gitlab.com/cryptsetup/cryptsetup.git 
	cd cryptsetup
	./autogen.sh
	./configure --prefix=/usr/local
	make
	make install
	ldconfig
	cd ..
	rm -r ./cryptsetup
fi 

# ~HERE BE DRAGONS!~ 

# this cipher is needed to take advantage of the marvell CESA module 
echo -e "Creating crypt container(s).\nEnter passkey when prompted…" 2>&1 | tee $LOG 
cryptsetup -v -y -c aes-cbc-essiv:sha256 -s 256 --sector-size 512 --type luks2 luksFormat /dev/sda 2>&1 | tee $LOG
cryptsetup luksOpen /dev/sda sda-crypt 2>&1 | tee $LOG
cryptsetup -v -y -c aes-cbc-essiv:sha256 -s 256 --sector-size 512 --type luks2 luksFormat /dev/sdb 2>&1 | tee $LOG
cryptsetup luksOpen /dev/sdb sdb-crypt 2>&1 | tee $LOG

# create and add keyfile
# may be worth investigating storing the keyfile in NAND flash or similar.
dd if=/dev/urandom of=/root/keyfile bs=4096
chmod 0400 /root/keyfile
cryptsetup luksAddKey /dev/sda /root/keyfile 2>&1 | tee $LOG
cryptsetup luksAddKey /dev/sda /root/keyfile 2>&1 | tee $LOG

echo "sda-crypt PARTUUID=$(lsblk /dev/sda -o partuuid -n) $CONTAINER /root/keyfile luks2" > /etc/crypttab
echo "sdb-crypt PARTUUID=$(lsblk /dev/sdb -o partuuid -n) $CONTAINER /root/keyfile luks2" >> /etc/crypttab

echo -e "Wipe the crypt containers to make the empty space on the disk cryptographically random\nThis will take a while..." 2>&1 | tee $LOG
for Dev in /sys/block/sd* ; do 
	dd if=/dev/urandom of=/dev/mapper/${Dev##*/}-crypt status=progress conv=sync,notrunc,noerror 2>&1 | tee $LOG &
done

echo -e "Waiting for crypt container wipes to complete.\n This may take a long time!" 2>&1 | tee $LOG
while [ -n "$(ps -aux | grep '[d]d if=/dev/urandom')" ]; do
	i=$(( (i+1) %4 ))
	printf "\r${spin:$i:1}"
	sleep .1
done
echo -e"Done!\n" 2>&1 | tee $LOG

# the swap is just to supplement the RAM on the LS421DE without destroying any flash devices with repeated writes 
# if you've got the disks and the means, why not use it? 
echo "Setting up LVM2 on both disks and creating swap." 2>&1 | tee $LOG
pvcreate /dev/mapper/sda-crypt 2>&1 | tee $LOG
vgcreate disk1 /dev/mapper/sda-crypt 2>&1 | tee $LOG
lvcreate -L 512M -n swap disk1 2>&1 | tee $LOG
lvcreate -L 100%VG -n root disk1 2>&1 | tee $LOG
pvcreate /dev/mapper/sdb-crypt 2>&1 | tee $LOG
vgcreate disk2 /dev/mapper/sdb-crypt 2>&1 | tee $LOG
lvcreate -L 512M -n swap disk2 2>&1 | tee $LOG
lvcreate -L 100%VG -n root disk2 2>&1 | tee $LOG

echo "Setting up the btrfs RAID1." 2>&1 | tee $LOG
mkfs.btrfs /dev/disk1/root 2>&1 | tee $LOG
mkdir /mnt/$CONTAINER 2>&1 | tee $LOG 
mount -o compression=zstd,autodefrag /dev/disk1/root /mnt/$CONTAINER 2>&1 | tee $LOG #note that ZSTD compression required kernel 4.14 or newer
btrfs device add /dev/disk2/root /mnt/$CONTAINER 2>&1 | tee $LOG
btrfs filesystem label /mnt/$CONTAINER $CONTAINER 2>&1 | tee $LOG
btrfs fileystem balance start -dconvert=raid1 -mconvert=raid2 /mnt/$CONTAINER 2>&1 | tee $LOG 

# as for the compression, zstd isn't the only compression routine, you can also use zlib and lzo.
# also, in kernel 5.1 and newer, you can set compression levels via mounting options.
# e.g. mount -o compression=zstd:9
# the minimum compression level is 3, the maximum is 15.
# note that using compression levels higher than 9 nets rapidly diminishing returns on compression vs. performance.

echo "Adding RAID volume and disk swap to fstab." 2>&1 | tee $LOG
echo "
UUID=$(lsblk /dev/disk1/root -o uuid -n)	/mnt/$CONTAINER	btrfs defaults,compression=zstd:9,autodefrag	0	0
UUID=$(lsblk /dev/disk1/swap -o uuid -n)	none	swap sw	0	0
" >> /etc/fstab
update-initramfs -u 2>&1 | tee $LOG
 
echo -e "All done!\nConsider setting up Bees (https://github.com/Zygo/bees) to take advantage of btrfs deduplication, before copying any data to the array.\nI'd also recommend rebooting and checking the disks are decrypted and mounted automatically on boot.\nAnd finally, you can check on the array by running btrfs filesystem usage /mnt/$CONTAINER\nHappy Hacking!" 2>&1 | tee $LOG

exit 0 