#!/bin/sh

# Armbian zram and log2zram installer script
# Requires Debian Jessie or newer
# By Franics Theodore Catte, 2019.

# copy armbian scripts
mkdir /usr/lib/armbian
cp ./armbian-ramlog /usr/lib/armbian
cp ./armbian-zram-config /usr/lib/armbian
cp ./armbian-truncate-logs /usr/lib/armbian

# copy default configs
cp ./armbian-zram.dpkg-dist /etc/default/armbian-zram
cp ./armbian-ramlog-config.dpkg-dist /etc/default/armbian-ramlog-config

# setup cronjobs
cp ./armbian-log-truncate /etc/cron.d/
cp ./armbian-ram-logging /etc/cron.daily/
systemctl restart cron

# setup systemd services
cp ./armbian*.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable armbian-ramlog
systemctl enable armbian-zram-config
systemctl start armbian-ramlog
systemctl start armbian-zram-config

