#!/bin/bash

iface="enp6s0" # your primary network interface
dns="172.0.0.15" # this either must be your DC or a DNS server with records for your DC!!!
dc_fqdn="samba-ad-dc1@pixelscastle.local"
domain="pixelscastle.local"

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root!"
    exit 1
fi

echo "Setting DNS..."
nmcli con mod $iface ipv4.dns $dns
nmcli con mod $iface ipv4.ignore-auto-dns yes
#nmcli con down $iface && nmcli con up $iface # danger!!

if ! [ 'dpkg-query -W -f='${Package}\n' realmd sssd sssd-tools libnss-sss libpam-sss krb5-user adcli samba-common-bin' ] ; then
	apt update
	apt upgrade -y
	apt -y install realmd sssd sssd-tools libnss-sss libpam-sss krb5-user adcli samba-common-bin
fi

echo -e "dns_lookup_realm = false\ndns_lookup_kdc = true\nrdns = false" >> /etc/krb5.conf

echo "Setting NTP
echo -e '[Time]\nNTP=$dc_fqdn' > /etc/systemd/timesyncd.conf
timedatectl set-ntp true
systemctl restart systemd-timesyncd
timedatectl --adjust-system-clock

echo "Running pam-auth-update; make sure to enable creating home folders on login!"
pam-auth-update

realm discover $domain
echo "Enter your domain's administrator password to join the domain:"
realm join --verbose -U administrator $domain

cp /etc/sssd/sssd.conf /etc/sssd/sssd/conf.bak
sed -i -r 's/use_fully_qualified_names = True/use_fully_qualified_names = False/' /etc/sssd/sssd.conf
sed -i -r 's/fallback_homedir = \/home\/\%u\@\%d/fallback_homedir = \/home\/\%d\/\%u/' /etc/sssd/sssd.conf
echo -e 'ldap_id_mapping = False\nldap_idmap_autorid_compat = False' >> /etc/sssd/sssd.conf
systemctl restart sssd

echo 'Now joined to $domain!'
