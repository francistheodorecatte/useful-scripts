#!/bin/bash

source functions.sh

# create optimally aligned GPT partitions
echo "Setting up partitions…" 2>&1 | tee $LOG
for Dev in /sys/block/sd* ; do
	parted -s /dev/${Dev##*/} mklabel gpt 2>&1 | tee $LOG \
	&& parted -a optimal -s /dev/${Dev##*/} mkpart primary 0% 100% 2>&1 | tee $LOG \
	&& sleep 2
done

echo "Assembling RAID array…" 2>&1 | tee $LOG
disks=()
for Dev in /sys/block/sd* ; do
	disks+=("/dev/${Dev##*/}")
done

# create an md RAID
yes | mdadm --create --verbose /dev/$MDARRAY --level=1 --raid-devices=${#disks[@]}  ${disks[*]} 2>&1 | tee $LOG

spin='-\|/'
echo -e "Waiting for initial RAID sync to complete.\n This may take a long time!" 2>&1 | tee $LOG
while [ -n "$(mdadm --detail /dev/$MDARRAY | grep -ioE 'State :.*resyncing')" ]; do
	i=$(( (i+1) %4 ))
	printf "\r${spin:$i:1}"
	sleep .1
done

echo "RAID sync complete!" 2>&1 | tee $LOG
