#!/bin/bash

# ABOUT:
# btrfs over md RAID56 health check
# this is similar to what Synology seems to do on their NAS'
# necessary until btrfs RAID56 is safe to use in production
# see the btrfs status page for more info: https://btrfs.wiki.kernel.org/index.php/Status#RAID56
# runs an md resync (scrub) if btrfs reports any errors
# btrfs has no direct control over the data on the disks when running over md, hence why this is needed
# it's recommend to run a monthly md resync anyway to prevent silent data corruption
# e.g. put this in crontab: @monthly echo check > /sys/block/md0/md/sync_action

# USAGE:
# after editing to fit your needs, in crontab add a line like:
# @hourly /root/raid_healthcheck.sh
# adding a MAILTO=admin@yourserver.local is recommended!

# NOTES:
# in my setup I'm running a luks container over the md RAID6, hence the /dev/mapper device
# see my raid_setup.sh script for more information.
# edit the md array and block devices to match your setup!

# prevent running the script if the mount point doesn't exist or is read-only
# the former could happen if your crypt container isn't open
# or the filesystem failed to mount on boot
# read only probably means bad things happened (either this script triggered or fs panic)
# check if that read-only check actually works, btw
if ! { 'mountpoint /mnt/five-nines' } || {"grep '^ro$' /proc/fs/*/five-nines/options"; then
	exit 1
fi

# exit if there's a sync already running
if { "$(mdadm --detail /dev/md0 | grep -ioE 'State :.*resyncing')" }; then
	exit 1
fi

# if any of the btrfs devices stats are non-zero run an md scrub.
if ! { "btrfs device stats /mnt/five-nines | grep -vE ' 0$'" }; then
	echo check > /sys/block/md0/md/sync_action

	spin='-\|/'
	while [ -n "$(mdadm --detail /dev/md0 | grep -ioE 'State :.*resyncing')" ]; do
		i=$(( (i+1) %4 ))
		printf "\r${spin:$i:1}"
		sleep .1
	done

	# read only needed to keep btrfs check from panicking
	echo "md scrub finished, remounting as RO and running btrfs check." 2>&1
	mount -o remount,ro /dev/mapper/five-nines /mnt/five-nines

	# using mode lowmem because with a huge filesystem a check could cause an out of memory error...
	# if the check fails it'll return a non-zero value and this if statement will trigger
	if ! { 'btrfs check --mode=lowmem --force --read-only /mnt/five-nines' }; then
		echo "btrfs check failed! leaving filesystem read-only to prevent further dataloss!" 2>&1
		echo "investigate further by checking disk health and running btrfs check manually." 2>&1
		exit 1
	else
		echo "btrfs check came back clean! remounting as RW." 2>&1
		mount -o remount,rw /dev/mapper/five-nines /mnt/five-nines
	fi
fi

exit 0
