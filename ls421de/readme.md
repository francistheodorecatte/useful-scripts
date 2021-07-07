some scripts for setting up a Buffalo LinkStation 421DE (LS412DE) running Debian Buster. this (should) work on any other Marvell Armada 370-based 2 or 4 bay NAS's if you're willing to modify it, however.

I will note; the LUKS2 + LVM + btrfs RAID script requires soldering on a micro-SD card slot, running jumper wires to enable the serial header (and soldering in the serial header), modifying the U-Boot envars, and installing Debian to an SD card. this could work with a rootfs on the hard drives, but would require extra (manual) work during the initial install.

for those of you willing to do some soldering, I'll put together a writeup on how to enable mmcboot and install Debian to an SD card at a later date.