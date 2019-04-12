#!/bin/bash

PLEX_HOME="/var/lib/plexmediaserver"

if ! [ -x "$(command -v sqlite3)" ]; then
	apt update
	apt -y install sqlite3
fi

cd $PLEX_HOME/Library/Application\ Support/Plex\ Media\ Server/Plug-in\ Support/Databases/

echo "Stopping plexmediaserver..."
systemctl stop plexmediaserver

echo "Checking for DB Corruption..."
cp com.plexapp.plugins.library.db com.plexapp.plugins.library.db.original
sqlite3 com.plexapp.plugins.library.db "DROP index 'index_title_sort_naturalsort'"
sqlite3 com.plexapp.plugins.library.db "DELETE from schema_migrations where version='20180501000000'"
sqlite3 com.plexapp.plugins.library.db "PRAGMA integrity_check"

echo "Running repairs..."
cp com.plexapp.plugins.library.db com.plexapp.plugins.library.db.original
sqlite3 com.plexapp.plugins.library.db "DROP index 'index_title_sort_naturalsort'"
sqlite3 com.plexapp.plugins.library.db "DELETE from schema_migrations where version='20180501000000'"
sqlite3 com.plexapp.plugins.library.db .dump > dump.sql
rm com.plexapp.plugins.library.db
sqlite3 com.plexapp.plugins.library.db < dump.sql

echo "Cleaning up..."
rm dump.sql
mv com.plexapp.plugins.library.db-shm com.plexapp.plugins.library.db-shm.original
mv com.plexapp.plugins.library.db-wal com.plexapp.plugins.library.db-wal.original

echo "Starting plexmediaserver..."
systemctl restart plexmediaserver

echo "Creating cron.daily script to restart plexmediaserver..."
echo "#!/bin/sh" > /etc/cron.daily/plexmediaserver
echo "systemctl restart plexmediaserver" >> /etc/cron.daily/plexmediaserver
chmod 755 /etc/cron.daily/plexmediaserver
chmod u+x /etc/cron.daily/plexmediaserver
