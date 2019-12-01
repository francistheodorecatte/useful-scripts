#!/bin/bash

source functions.sh

echo -e "Running disk checks\nThis may take a very long time!" 2>&1 | tee $LOG
for Dev in /sys/block/sd* ; do
	echo -e "Checking /dev/${Dev##*/} for bad blocks..." 2>&1 | tee $LOG
        badblocks -sv -b 4096 -t 0x00 -o ./badblocks_${Dev##*/}.txt /dev/${Dev##*/} 2>&1 | tee $LOG \
        && smartctl -t short -C /dev/${Dev##*/} 2>&1 | tee $LOG \
	&& sleep 121 \ #wait two minutes for test to show in disk's SMART log
        && smartctl -H /dev/${Dev##*/} 2>&1 | tee $LOG \
        && smartctl -l selftest /dev/${Dev##*/} 2>&1 | tee $LOG \
        && sleep 2
done

