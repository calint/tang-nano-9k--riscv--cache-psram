#!/bin/bash
set -e
set -x

cd $(dirname "$0")

TTY=/dev/ttyUSB1
SLP=1

stty -F $TTY 9600 cs8 -cstopb -parenb -crtscts -ixon -ixoff -ignbrk -brkint -icrnl -opost -isig -icanon -iexten -echo -echoe -echok -echoctl -echoke
#    -crtscts disables hardware flow control
#    -ixon -ixoff disables software flow control
#    -ignbrk -brkint ignores break conditions
#    -icrnl ensures that carriage return characters are not translated to newlines
#    -opost disables output processing (output will be sent as-is)
#    -isig -icanon -iexten disables terminal signal handling and canonical input processing
#    -echo -echoe -echok -echoctl -echoke disables terminal echoing

cat $TTY > test1.out &

read -p "program fpga then press enter to continue"

printf "i\r" > $TTY
sleep $SLP
printf "t notebook\r" > $TTY
sleep $SLP
printf "n\r" > $TTY
sleep $SLP
printf "t lighter\r" > $TTY
sleep $SLP
printf "g mirror u\r" > $TTY
sleep $SLP
printf "i\r" > $TTY
sleep $SLP
printf "i\r" > $TTY
sleep $SLP

# send SIGTERM (termination signal) to 'cat'
kill -SIGTERM %1

# wait for 'cat' to exit
wait %1 || true

if cmp -s test1.diff test1.out; then
    echo "test 1: OK"
    rm test1.out
else
    echo "test 1: FAILED"
fi
