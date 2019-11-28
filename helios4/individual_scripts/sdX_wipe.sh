#!/bin/bash

source functions.sh

echo -e "Wiping all disks…\nThis may take a very long time!" 2>&1 | tee $LOG
for Dev in /sys/block/sd* ; do
	echo -e "Wiping /dev/${Dev##*/}" 2>&1 | tee $LOG
	pv -tpreb /dev/zero | dd of=/dev/${Dev##*/} bs=4096 conv=notrunc,noerror 2>&1 | tee $LOG && sleep 2
done
