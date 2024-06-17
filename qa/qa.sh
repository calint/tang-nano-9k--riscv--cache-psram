#!/bin/sh
set -e
cd $(dirname "$0")

NUM_TESTS=7

for i in $(seq 1 $NUM_TESTS); do
    ./test-bench.sh $i 2>&1 | grep -v -E "passed|readmemh|VCD|finish|prim_tsim|sorry: constant selects in always"
done
