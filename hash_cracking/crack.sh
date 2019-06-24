#!/bin/bash

# run hashcat for FOO number of seconds and break the loop
# then restart the script

runtime=86400
mode=500
pwmin=6
pwmax=15
SECONDS=0

while (( $SECONDS < $runtime)); do
	shuf ./dictionary.txt | ./pp64.bin --pw-min=$pwmin --pw-max=$pwmax | hashcat -m $mode -w 4 -a 0 --generate-rules-func-min=999 --generate-rules-func-max=300000 -O -o password.out password.hash
done

killall hashcat
killall shuf
killall pp64

exec bash "$0" "$@"

exit 0

