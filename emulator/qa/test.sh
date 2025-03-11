#!/bin/sh
set -e
cd $(dirname "$0")

../make.sh

./compile.sh ram.S

CMD="g++ -std=c++23 -O3 $@ -fno-rtti -fno-exceptions -Wfatal-errors -Werror -Wall -Wextra -Wpedantic \
    -Wconversion -Wsign-conversion -Wswitch-default \
    -o test main.cpp"
#echo
#echo $CMD
#echo
$CMD

./test

echo "test: PASSED"