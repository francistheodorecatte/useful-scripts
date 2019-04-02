#!/bin/sh

# Domain cleanup script
# By Franics Theodore Catte, 2019
# Will leave your system's Samba config in more-or-less a clean-slate state
# This includes purging kerberos and winbind!

echo "WARNING!!! THIS SCRIPT WILL REMOVE ANY AND ALL SAMBA ACTIVE DIRECTORY DOMAINS!"
read -p "Press any key to continue... " -n1 -s
systemctl stop samba-ad-dc
apt-get purge krb5-config winbind
# backup samba config just in case
mv /etc/samba/smb.conf /etc/samba/smb.conf.org
# restore default samba config
cp /usr/share/samba/smb.conf /etc/samba/smb.conf
# remove samba-ad-dc files
rm /var/lib/samba/private/*.ldb
rm /var/lib/samba/private/*.tdb
rm -r /var/lib/samba/private/sam.ldb.d/
rm -r /var/lib/samba/sysvol/*
rm /var/lib/samba/private/krb5.conf
rm /var/lib/samba/private/secrets.keytab
# remove kerberos configs if not already removed
rm /etc/krb5.keytab
rm /etc/krb5.conf
# disable samba-ad-dc and restore smbd, nmbd, and winbind
systemctl mask samba-ad-dc
systemctl disable samba-ad-dc
systemctl unmask smbd nmbd winbind
systemctl enable smbd nmbd winbind
systemctl start smbd nmbd winbind
echo "Domain cleaned. To reprovision any domains, run domain_provision.sh"