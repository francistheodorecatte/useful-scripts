#!/bin/bash
source functions.sh

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
pv -tpreb /dev/zero | dd of=/dev/mapper/$CONTAINER bs=4096 conv=notrunc,noerror

# again, set the block size to 4096 to reduce IO (and match the LUKS container)
echo "Formatting crypt container as btrfs…" 2>&1 | tee $LOG
mkfs.btrfs -s 4096 -d single -L $CONTAINER /dev/mapper/$CONTAINER

echo "Mounting btrfs partition to /mnt/$CONTAINER" 2>&1 | tee $LOG
mkdir /mnt/$CONTAINER
mount -o compression=zstd,autodefrag /dev/mapper/$CONTAINER /mnt/$CONTAINER	#note that ZSTD compression required kernel 4.14 or newer

# as for the compression, zstd isn't the only compression routine, you can also use zlib and lzo.
# also, in kernel 5.1 and newer, you can set compression levels via mounting options.
# e.g. mount -o compression=zstd:9
# the minimum compression level is 3, the maximum is 15.
# note that using compression levels higher than 9 nets rapidly diminishing returns on compression vs. performance.

echo  -e "All done!\nTo mount the crypt container just type the following in terminal as root:\ncryptsetup luksOpen /dev/$MDARRAY $CONTAINER\nmount -o compression=zstd,autodefrag /dev/mapper/$CONTAINER /mnt/$CONTAINER" 2>&1 | tee $LOG

# if using this filesystem for samba shares, it's recommended to use btrfs subvolumes for shared folders
# this will allow per-share snapshots, and using the "previous history" feature in Windows.

exit 0
