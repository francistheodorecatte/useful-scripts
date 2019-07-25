#!/bin/bash

domain="PIXELSCASTLE"
realm="PIXELSCASTLE.LOCAL"
dc="samba-ad-dc1.pixelscastle.local"
sambacfg="${cat <<EOF
workgroup = $domain
realm = $realm
server string = %h
security = adspassword server = $dc
idmap config * : backend = tdb
idmap config * : range = 100000-9999999
idmap config $domain : backend = rid
idmap config $domain : range = 10000-20000
kerberos method = secrets and keytab
dns proxy = no
log file = /var/log/samba/log.%m
log level = 10
max log size = 1000
syslog = 0
panic action = /usr/share/samba/panic-action %d
passdb backend = tdbsam
obey pam restrictions = yes
unix password sync = yes
passwd program = /usr/bin/passwd %u
passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
pam password change = yes
map to guest = bad user
usershare allow guests = yes
vfs objects = acl_xattr
map acl inherit = yes
store dos attributes = yes
EOF
)"

echo "installing wsdd package from openmediavault usul"
wget -qO - http://packages.openmediavault.org/public/archive.key | apt-key add -
echo "deb http://packages.openmediavault.org/public usul main" > /etc/apt/sources.list.d/openmediavault.list
apt update && apt install -y wsdd
systemctl enable wsdd && systemctl start wsdd

echo "editing login.defs to raise UID and GID maxes to work with AD"
sed -i '/UID_MAX.*/UID_MAX	99999999/' /etc/login.defs
sed -i '/GID_MAX.*/GID_MAX	99999999/' /etc/login.defs

echo "backing up current samba config"
mv /etc/samba/smb.conf /etc/samba/smb.conf.bak
echo "creating new samba config and restarting smbd and nmbd"
echo $sambacfg > /etc/samba/smb.conf
systemctl restart smbd nmbd

echo "samba should be all set. edit /etc/samba/smb.conf and add shares as needed."
cat <<EOF > echo
If you're using btrfs as your file system, add shared folders like so:
btrfs subvolume create /mnt/five-nines/@test
brtfs subvolume create /mnt/five-nines/@test/.snapshots

The .snapshots directory allows creating and deleting snapshots like so:
brtfs subvolume snapshot -r /mnt/five-nines/@test /mnt/five-nines/@test/.snapshots/@GMT_`date +%Y.%m.%d-%H.%M.%S`
btrfs subvolume delete /mnt/five-nines/@test/.snapshots/@GMT_2015.07.31-14.01.20

Samba shares can be created by adding sections like the following to /etc/samba/smb.conf, then restarting samba and wsdd:
[test]
	comment = test
	path = /mnt/five-nines/@test
	vfs objects = shadow_copy2
	shadow:format = @GMT_%Y.%m.%d-%H.%M.%S
	shadow:sort = desc
	shadow:snapdir = .snapshots
	public = no
	writable = yes
	guest ok = no
	valid users = @"smbusers@pixelscastle.local"
EOF
