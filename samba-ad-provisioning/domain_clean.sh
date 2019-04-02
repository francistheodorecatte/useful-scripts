#!/bin/sh

# Domain cleanup script
# By Franics Theodore Catte, 2019
# Will leave your system's Samba config in more-or-less a clean-slate state
# This includes purging kerberos and winbind!

echo "WARNING!!! THIS SCRIPT WILL REMOVE ANY AND ALL SAMBA ACTIVE DIRECTORY DOMAINS!"
systemctl stop samba-ad-dc
apt-get purge krb5-config winbind
mv /etc/samba/smb.conf /etc/samba/smb.conf.orig
cp /usr/share/samba/smb.conf /etc/samba/smb.conf
rm /var/lib/samba/private/*.ldb
rm /var/lib/samba/private/*.tdb
rm -r /var/lib/samba/private/sam.ldb.d/
rm -r /var/lib/samba/sysvol/*
rm /etc/krb5.keytab
rm /etc/krb5.conf
rm /var/lib/samba/private/krb5.conf
rm /var/lib/samba/private/secrets.keytab
systemctl mask samba-ad-dc
systemctl unmask smbd
systemctl unmask nmbd
systemctl unmask winbind
systemctl start smbd
systemctl start nmbd
systemctl start winbind