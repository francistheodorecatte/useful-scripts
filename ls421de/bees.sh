#!/bin/bash

# automating the install of bees on your NAS
# this has the chance of being dangerous

USER="localadmin" #make sure this user has r/w permissions to the filesystem (setfacl -R -m u:$USER:rw /mnt/$FILESYSTEM)
UUID=$(lsblk /dev/disk1/root -o uuid -n) #the /dev/disk1/root should be set to whatever block device your btrfs filesystem resides on

# build bees
mkdir build
cd build
wget https://github.com/Zygo/bees/archive/refs/tags/v0.6.5.tar.gz
tar -xvf v0.6.5
cd v0.6.5
sudo apt update
sudo apt install -y build-essential btrfs-progs markdown libbtrfs-dev uuid-runtime
make
sudo make install
cd ..
rm -r ./v0.6.5

# overwrite the original systemd unit file with a modificated one
# this is to workaround some weirdness in the beesd script in regard to options with numbers
# and to make sure the service restarts if things go south
sudo cat <<'EOF' > /lib/systemd/system/beesd@.service
[Unit]
Description=Bees (%i)
Documentation=https://github.com/Zygo/bees
After=sysinit.target

[Service]
Type=simple
ExecStart=/usr/sbin/beesd ${UUID} %i
Environment=OPTIONS="--verbose=6 --scan-mode=2 --strip-paths"
CPUAccounting=true
CPUSchedulingPolicy=batch
CPUWeight=12
IOSchedulingClass=idle
IOSchedulingPriority=7
IOWeight=10
KillMode=control-group
KillSignal=SIGTERM
MemoryAccounting=true
Nice=19
Restart=on-failure
RestartSec=5s
StartupCPUWeight=25
StartupIOWeight=25

[Install]
WantedBy=basic.target
EOF

# set the UUID in the beesd.conf file
sed -i 's/\#UUID=/UUID\=${UUID}/g' /etc/bees/beesd.conf

# let loose the bees
sudo systemctl daemon-reload
sudo systemctl enable beesd@$USER.service
sudo systemctl start beesd@$USER.service

exit 0