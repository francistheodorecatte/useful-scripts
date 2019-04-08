#!/bin/bash
mkdir /img
dd if=/dev/zero of=/img/test.img bs=1 count=0 seek=343597400000  #320GiB  sparse  file  image
parted /img/test.img mklabel gpt
parted -a optimal /img/test.img mkpart primary 0% 100%
mkfs -t ext4 -L test /img/test.img

cp ./loop-setup /usr/lib/systemd/scripts/
cp ./loopsetup.service /etc/systemd/system/
systemd enable losetup.service

echo "After reboot, open the OMV webgui, go to filesystems, and mount the loop device!"
echo "You should now be able to put shared folders on this loop fs. :)"
read -p "Press any key to reboot! " -n1 -s
echo "Rebooting now!"
reboot
