#!/bin/bash

# a simple script to put together a basic dictionary of words and passwords.
# basically just to save a lot of typing.
# this pulls from lists provided by skull security.
# once downloaded, they're unpacked, and shuffled together into a single file.
# here, it's just dictionary.txt in the root of your home folder.

mkdir ~/wordlists
cd ~/wordlists
wget http://downloads.skullsecurity.org/passwords/john.txt.bz2
wget http://downloads.skullsecurity.org/passwords/cain.txt.bz2
wget http://downloads.skullsecurity.org/passwords/conficker.txt.bz2
wget http://downloads.skullsecurity.org/passwords/500-worst-passwords.txt.bz2
wget http://downloads.skullsecurity.org/passwords/twitter-banned.txt.bz2
wget http://downloads.skullsecurity.org/passwords/rockyou.txt.bz2
wget http://downloads.skullsecurity.org/passwords/phpbb.txt.bz2
wget http://downloads.skullsecurity.org/passwords/myspace.txt.bz2
wget http://downloads.skullsecurity.org/passwords/hotmail.txt.bz2
wget http://downloads.skullsecurity.org/passwords/faithwriters.txt.bz2
wget http://downloads.skullsecurity.org/passwords/elitehacker.txt.bz2
wget http://downloads.skullsecurity.org/passwords/hak5.txt.bz2
wget http://downloads.skullsecurity.org/passwords/facebook-pastebay.txt.bz2
wget http://downloads.skullsecurity.org/passwords/facebook-phished.txt.bz2
wget http://downloads.skullsecurity.org/passwords/carders.cc.txt.bz2
wget http://downloads.skullsecurity.org/passwords/english.txt.bz2
bunzip2 *.bz2
cat *.txt | shuf >> ~/dictionary.txt
