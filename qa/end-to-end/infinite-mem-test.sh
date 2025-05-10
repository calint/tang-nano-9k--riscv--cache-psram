#!/bin/bash
#
# note: when script fails `cat` process might be active reading from TTY 
#  do `ps aux | grep cat` and terminate the process
#
set -e
cd $(dirname "$0")

TTY=/dev/ttyUSB1
BAUD=115200
SLP=0.5

# capture ctrl+c and kill cat
trap 'kill $(jobs -p); exit 130' INT

stty -F $TTY $BAUD cs8 -cstopb -parenb -crtscts -ixon -ixoff -ignbrk -brkint -icrnl -opost -isig -icanon -iexten -echo -echoe -echok -echoctl -echoke
#    -crtscts disables hardware flow control
#    -ixon -ixoff disables software flow control
#    -ignbrk -brkint ignores break conditions
#    -icrnl ensures that carriage return characters are not translated to newlines
#    -opost disables output processing (output will be sent as-is)
#    -isig -icanon -iexten disables terminal signal handling and canonical input processing
#    -echo -echoe -echok -echoctl -echoke disables terminal echoing

cat $TTY | tee test.out &

while true; do
    printf "m\r" > $TTY
    sleep 10
done
