#!/bin/sh
set -e
cd $(dirname "$0")

TTY=${1-/dev/ttyUSB1}
BAUD=115200
SLP=0.1

stty --file $TTY $BAUD cs8 -cstopb -parenb -crtscts raw -echo
#   cs8: 8 data bits per character
#   -cstopb: 1 stop bit (the - disables 2 stop bits)
#   -parenb: no parity bit
#   -crtscts: disables RTS/CTS hardware handshaking
#   -echo: disables echoing of received input characters back to the sender

# stream serial port to terminal and log file
tee test.out <$TTY &
LOG_PID=$!

# ensure background logger is killed on ANY exit (normal, error, or Ctrl+C)
trap 'kill $LOG_PID 2>/dev/null || true' EXIT

echo "Assuming the FPGA opens $TTY at $BAUD baud, 8 data bits, 1 stop bit, no parity"
read -rsp $'Program or reset FPGA then press "Enter" to continue\n\n'

printf "i\r" >$TTY
sleep $SLP
printf "t notebook\r" >$TTY
sleep $SLP
printf "n\r" >$TTY
sleep $SLP
printf "t lighter\r" >$TTY
sleep $SLP
printf "g mirror u\r" >$TTY
sleep $SLP
printf "i\r" >$TTY
sleep $SLP
printf "i\r" >$TTY
sleep $SLP
printf "m\r" >$TTY
sleep 15
printf "i\r" >$TTY
sleep $SLP
printf "d lighter\r" >$TTY
sleep $SLP
printf "t lighter\r" >$TTY
sleep $SLP
printf "i\r" >$TTY
sleep $SLP
printf "i\r" >$TTY
sleep $SLP
printf "sds\r" >$TTY
sleep $SLP
printf "sdw 123 hello world\r" >$TTY
sleep $SLP
printf "sdr 123\r" >$TTY
sleep $SLP
printf "sdw 123 another hello world\r" >$TTY
sleep $SLP
printf "sdr 123\r" >$TTY
sleep $SLP
printf "sdw 1 sector 1\r" >$TTY
sleep $SLP
printf "sdr 1\r" >$TTY
sleep $SLP
printf "sdw 1 sector 1 again\r" >$TTY
sleep $SLP
printf "sdr 1\r" >$TTY
sleep $SLP
printf "sdr 123\r" >$TTY
sleep $SLP

# stop logger
kill $LOG_PID

if cmp --silent test.diff test.out; then
    echo
    echo
    echo "test: OK"
    rm test.out
else
    echo
    echo
    echo "test: FAILED, check 'diff --text test.diff test.out'"
fi
