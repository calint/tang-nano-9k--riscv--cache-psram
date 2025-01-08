#!/bin/sh
set -e
cd $(dirname "$0")

for i in 1 2 3 4 5 6 7 8; do
    echo -n "test $i: "
    ./testbench.sh $i 2>&1 | grep -E "PASSED|FATAL"
done
