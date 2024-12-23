#!/bin/sh
set -e
cd $(dirname "$0")

#echo "Making emulator"
#../../emulator/make.sh

echo "Running test for 5 seconds"
echo -e "$(cat test.in)" | timeout 5 ../../emulator/osqa ../os.bin > test.out || true

if cmp -s test.diff test.out; then
    echo "test: OK"
    rm test.out
else
    echo "test: FAILED, check 'diff test.diff test.out'"
fi
