#!/bin/sh

# Armbian zram and log2zram installer script
# Requires Debian Jessie or newer
# By Franics Theodore Catte, 2019.
# system_prep function borrowed in part from armbian-hardware-optimization script

# functions

system_prep() {
	# set io scheduler
	for i in $( lsblk -idn -o NAME | grep -v zram ); do
		read ROTATE </sys/block/$i/queue/rotational
		case ${ROTATE} in
			1) # mechanical drives
				echo cfq >/sys/block/$i/queue/scheduler
				echo -e "[\e[0;32m ok \x1B[0m] Setting cfg I/O scheduler for $i"
				;;
			0) # flash based
				echo noop >/sys/block/$i/queue/scheduler
				echo -e "[\e[0;32m ok \x1B[0m] Setting noop I/O scheduler for $i"
				;;
		esac
	done

	CheckDevice=$(for i in /var/log /var / ; do findmnt -n -o SOURCE $i && break ; done)
	# adjust logrotate configs
	if [[ "${CheckDevice}" == "/dev/zram0" || "${CheckDevice}" == "armbian-ramlog" ]]; then
		for ConfigFile in /etc/logrotate.d/* ; do sed -i -e "s/\/log\//\/log.hdd\//g" "${ConfigFile}"; done
		sed -i "s/\/log\//\/log.hdd\//g" /etc/logrotate.conf
	else
		for ConfigFile in /etc/logrotate.d/* ; do sed -i -e "s/\/log.hdd\//\/log\//g" "${ConfigFile}"; done
		sed -i "s/\/log.hdd\//\/log\//g" /etc/logrotate.conf
	fi

	# unlock cpuinfo_cur_freq to be accesible by a normal user
	prefix="/sys/devices/system/cpu/cpufreq"
	for f in $(ls -1 $prefix 2> /dev/null)
	do
		[[ -f $prefix/$f/cpuinfo_cur_freq ]] && chmod +r $prefix/$f/cpuinfo_cur_freq 2> /dev/null
	done
	# older kernels
	prefix="/sys/devices/system/cpu/cpu0/cpufreq/"
	[[ -f $prefix/cpuinfo_cur_freq ]] && chmod +r $prefix/cpuinfo_cur_freq 2> /dev/null

	# enable compression where not exists
	find /etc/logrotate.d/. -type f | xargs grep -H -c 'compress' | grep 0$ | cut -d':' -f1 | xargs -L1 sed -i '/{/ a compress'
	sed -i "s/#compress/compress/" /etc/logrotate.con


	# tweak ondemand cpufreq governor settings to increase cpufreq with IO load
	grep -q ondemand /etc/default/cpufrequtils
	if [ $? -eq 0 ]; then
		echo ondemand >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
		cd /sys/devices/system/cpu
		for i in cpufreq/ondemand cpu0/cpufreq/ondemand cpu4/cpufreq/ondemand ; do
			if [ -d $i ]; then
				echo 1 >${i}/io_is_busy
				echo 25 >${i}/up_threshold
				echo 10 >${i}/sampling_down_factor
				echo 200000 >${i}/sampling_rate
			fi
		done
	fi
}

# housekeeping
system_prep
apt -y install rsync

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

