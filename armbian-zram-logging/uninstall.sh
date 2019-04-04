#!/bin/sh

# armbian zram logging removal script
# Francis Theodore Catte, 2019

echo "Stopping and disabling services..."
systemctl stop armbian-ramlog armbian-zram-config
systemctl disable armbian-armlog armbian-zram-config
echo "Removing all installed files..."
rm /etc/cron.d/armbian-truncate-logs
rm /etc/cron.daily/armbian-ram-logging
rm /etc/default/armbian-*
rm /etc/armbian-release
rm /etc/systemd/system/armbian-*.service
rm -r /usr/lib/armbian
echo "Reloading systemd..."
systemctl daemon-reload
systemctl restart cron
echo "All done."


