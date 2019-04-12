#!/bin/bash

# Samba AD-DC domain provisioning helper script
# Franics Theodore Catte April 2019

# variables
DOMAIN='DOMAIN'
TLD='LOCAL'
ADMINPASS='Passw0rd'
TIMEZONE='America/New_York'
DNSFORWARDERIP='172.0.0.1'

# this script assumes you're using Debian Stretch on an embedded device and have some modicum of experience with the following
# read this script over carefully and edit as needed BEFORE USING IT!!
# also, make sure your device has a static IP before starting (this should be obvious but a DHCP address on a DC is not good!)

echo "Starting domain creation script"
echo "Doing some housekeeping..."

# check if these packages are installed
if ! [ 'dpkg-query -W -f='${Package}\n' samba krb5-config winbind smbclient ntp openssh-server unattended-upgrades apt-listchanges 2>/dev/null' ] ; then
	apt update
	apt upgrade -y
	apt -y install samba krb5-config winbind smbclient ntp openssh-server unattended-upgrades apt-listchanges # if any aren't, install them.
fi

# the following enables unattended security updates
# comment out if you intend on manually applying security updates to your domain controller...
echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
dpkg-reconfigure -f noninteractive unattended-upgrades
# enabling ssh if not already configured
# consider hardening your sshd config by disabling root logins, changing the port, etc.
systemctl start ssh
systemctl enable ssh

# note that this will not work with networkmanager, resolvconf, resolved, etc.
# on a server I'd recommend disabling those anyway.
echo "Setting up local DNS..."
echo -e 'domain $DOMAIN.$TLD\nsearch $DOMAIN.$TLD\nnameserver $DNSFORWARDERIP' > /etc/resolv.conf

echo "Setting up NTP..."
# set local timezone
timedatectl set-timezone $TIMEZONE
# backup default ntp config
mv /etc/ntp.conf /etc/ntp.conf.org
# add US NTP servers
# change these to whatever ntp servers are geographically closest to you
echo -e 'pool 0.us.pool.ntp.org iburst\npool 1.us.pool.ntp.org iburst\npool 2.us.pool.ntp.org iburst\npool 3.us.pool.ntp.org iburst' > /etc/ntp.conf
# restrict to local subnets only (172.0.0.0 in my case), and disable panicking since embedded devices typically have no realtime clock and syncing internet time may take a while on cold boots!
echo -e 'restrict 172.0.0.0 mask 255.255.0.0 nomodify notrap\ndriftfile       /var/lib/ntp/ntp.drift\nlogfile         /var/log/ntp\nntpsigndsocket  /usr/local/samba/var/lib/ntp_signd/\ntinker panic 0' >> /etc/ntp.conf
systemctl restart ntp
systemctl enable ntp

echo "Provisioning domain..."
# backup samba config
mv /etc/samba/smb.conf /etc/samba/smb.conf.org
samba-tool domain provision --realm=$DOMAIN.$TLD --domain=$DOMAIN --server-role=dc --dns-backend=SAMBA_INTERNAL --adminpass=$ADMINPASS --use-rfc2307 --debuglevel=3
cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
# because there's no switch to do this non-interactively in domain provision:
sed s/127.0.0.1/$DNSFORWARDERIP/g /etc/samba/smb.conf 

echo "Disabling smbd, nmbd, and winbind..."
systemctl stop smbd nmbd winbind
systemctl mask smbd nmbd winbind
systemctl disable smbd nmbd winbind
echo "Enabling samba-ad-dc..."
systemctl unmask samba-ad-dc
systemctl start samba-ad-dc
systemctl enable samba-ad-dc

echo "Now setting up accounts and groups..."
# Disabling password expiration on the Administrator account.
samba-tool user setexpiry Administrator --noexpiry
# set default password rules for domain
samba-tool domain passwordsettings set --history-length=3 #only store three prior passwords
samba-tool domain passwordsettings set --min-pwd-length=8 #set the minimum password length to 8 characters
samba-tool domain passwordsettings set --min-pwd-age 0 #disable variable password expiry
samba-tool domain passwordsettings set --max-pwd-age 365 #set the password expiration to 1 year

# this is going to be specific to you; the following is just to be used as an example!
# Note that user creation is interactive-- you have to enter user passwords manually.
# consider using the --must-change-at-next-login switch for new user accounts.
echo "Creating user John:"
samba-tool user create john --given-name=John --surname=Doe--initials=JD
echo "Creating user serviceaccount:"
samba-tool user create serviceaccount
echo "Creating groups and adding users..."
samba-tool group add smbusers
samba-tool group addmembers "smbusers" john,serviceaccount
samba-tool group addmembers "Domain Admins" john
echo "All done! Join a Windows PC to the domain and use ADUC to manage!"
echo "Make sure to change the primary DNS on any PCs you join to this domain to the IP of this device!"
