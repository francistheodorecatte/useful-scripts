## What the hell is this
This is what happens when you want to crack the shadow file on an embedded linux device and need more non-deterministic output in your life.

AKA using the PRINCE Processor to randomly generate new wordlists for Hashcat, over and over, until something sticks.

## USAGE:
* copy pp64.bin, password.hash, and dictionary.txt to the crack.sh working directory.
* edit the runtime variable in crack.sh to the seconds equivalent to 1-24 hours.
* edit the mode variable to match the hash you're cracking; default is 500 (MD5). look at the hashcat help file for more info on the different modes.
* run crack.sh and wait a while; eventually you should see something in password.out.

Additionally, you can edit the pwmin and pwmax variables to change the minimum and maximum password lengths PRINCE will create.

The faster the hardware you have, the shorter you should make the runtime. Conversely, the slower the hardware, the longer you should make the runtime.

## REQUIREMENTS:
* OpenCL compatible CPU, GPU, or FPGA hardware.
* OpenCL runtime(s) and Hashcat installed. see https://hashcat.net/hashcat/ for more info on that.
* password.hash - a file with the hash(es) you want to crack; e.g. the hashes from a linux shadow file. one hash per line.
* dictionary.txt - a password dictionary file; e.g. rockyou.txt (see https://wiki.skullsecurity.org/Passwords or https://weakpass.com/wordlist). this can be multiple wordlists merged together, as well.
* pp64.bin - a built binary of the PRINCE Processor (see https://github.com/hashcat/princeprocessor)

It's highly recommended to keep your wordlist under 500MiB. Any more and you'll massively reduce efficiency.
