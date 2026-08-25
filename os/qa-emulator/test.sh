#!/bin/sh
set -e
cd $(dirname "$0")

echo "* building emulator"
../../emulator/make.sh

EMULATOR=../../emulator/osqa
FIRMWARE=../os.bin
SDCARD=../../notes/samples/sample.txt

echo " * running test for 2 seconds"
echo -e "$(cat test.in)" | timeout 2 $EMULATOR $FIRMWARE $SDCARD >test.out || true

if cmp --silent test.diff test.out; then
    echo "test: PASSED"
    rm test.out
else
    echo "test: FAILED, check 'diff test.diff test.out'"
fi
