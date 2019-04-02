#!/bin/sh
mkdir /usr/lib/armbian
cp ./armbian-ramlog /usr/lib/armbian
cp ./armbian-zram-config /usr/lib/armbian
cp ./armbian-truncate-logs /usr/lib/armbian
cp ./armbian-log-truncate /etc/cron.d/
cp ./armbian-ram-logging /etc/cron.daily/
cp ./armbian*.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable armbian-ramlog
systemctl enable armbian-zram-config
echo "WARNING!!! Going down for reboot!"
reboot

