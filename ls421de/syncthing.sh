#!/bin/bash

# forcing syncthing to be more than a dumbass desktop applet
# heaven forbid you use this on a headless NAS

USER="localadmin"

sudo apt update
sudo apt install -y syncthing

# dump their unit file in place since Debian doesn't package syncthing with it
sudo cat <<'EOF' > /lib/systemd/system/syncthing@.service
[Unit]
Description=Syncthing - Open Source Continuous File Synchronization for %I
Documentation=man:syncthing(1)
After=network.target
StartLimitIntervalSec=60
StartLimitBurst=4

[Service]
User=%i
ExecStart=/usr/bin/syncthing serve --no-browser --no-restart --logflags=0
Restart=on-failure
RestartSec=1
SuccessExitStatus=3 4
RestartForceExitStatus=3 4

# Hardening
ProtectSystem=full
PrivateTmp=true
SystemCallArchitectures=native
MemoryDenyWriteExecute=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

# just in case?
sudo -U $USER mkdir /home/$USER/.config
sudo -U $USER mkdir /home/$USER/.config/syncthing

# now to enable it
sudo systemctl daemon-reload
sudo systemctl enable syncthing@$USER.service
sudo systemctl start syncthing@$USER.service

sleep 20

# just need to change the gui client to listen on all interfaces
# it should come up at whatever.your.ip.is:8384 once the script says "Job Done!"
sudo systemctl stop syncthing@$USER.service
sudo -U $USER sed -i 's/127.0.0.1/0.0.0.0/g' /home/$USER/.config/syncthing/config.xml
sudo systemctl start syncthing@$USER.service

echo "Job Done!"
exit 0