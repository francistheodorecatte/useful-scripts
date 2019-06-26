#!/bin/bash

# Script to install duperemove and setup a cron script to run it daily

btrfs_root="/mnt/five-nines"	#change to your btrfs mount root
blksz=4096			#change to your filesystem blocksize

if [[ $EUID -ne 0 ]]; then
	echo -e "You need to run this script as root, or with sudo!\nExiting..."
	exit 1
fi

# check if duperemove is installed
# this assumes /usr/local/sbin is in your $PATH
if !['command -v duperemove']; then
	if ['command -v git']; then
		git clone https://github.com/markfasheh/duperemove.git
		cd duperemove
		make
		make install
		cd ..
		rm -r duperemove
	else
		echo "Please make sure git is installed, then rerun this script!"
		exit 1
	fi
fi

# check if the cron file already exists
if !/etc/cron.daily/dedupe
	cat > /etc/cron.daily/dedupe << EOF
#/bin/sh
btrfs filesystem defragment -r /mnt/$btrfs_root/
duperemove -dr --hashfile=/mnt/$btrfs_root/hashfile.db -b $blksz --skip-zeroes
exit 0
EOF

	chmod 755 /etc/cron.daily/plexmediaserver
	chmod u+x /etc/cron.daily/plexmediaserver

	exit 0
fi

exit 1
