#!/bin/bash

LOG="./raid_setup.log"
CONTAINER="five-nines"
MDARRAY="md0"
RAIDLEVEL=5
USER=$(logname)

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
