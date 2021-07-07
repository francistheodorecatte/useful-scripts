some scripts for setting up a Buffalo LinkStation 421DE running Debian Buster

the LUKS2 + LVM + btrfs RAID script requires soldering on a micro-SD card slot, modifying the U-Boot envars, and installing Debian to an SD card. this could work with a rootfs on the hard drives, but would require extra (manual) work during the initial install.