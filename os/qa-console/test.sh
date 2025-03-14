#!/bin/sh
set -e
cd $(dirname "$0")

SDCARD=../../notes/samples/sample.txt

echo -e "$(cat test.in)" | ../console_application $SDCARD > test.out

if cmp -s test.diff test.out; then
    echo "test: PASSED"
    rm test.out
else
    echo "test: FAILED, check 'diff test.diff test.out'"
fi
