#!/bin/bash
set -e
cd $(dirname "$0")

../os-console < test.in > test.out

if cmp -s test.diff test.out; then
    echo "test: OK"
    rm test.out
else
    echo "test: FAILED, check 'diff test.diff test.out'"
fi
