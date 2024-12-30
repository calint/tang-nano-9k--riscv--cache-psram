#!/bin/bash
#
# tools used:
#        g++: 14.2.1 20240910
#
set -e
cd $(dirname "$0")

CMD="g++ -std=c++23 -O3 $@ -fno-rtti -fno-exceptions -Wfatal-errors -Werror -Wall -Wextra -Wpedantic \
    -Wswitch-default -Wconversion \
    -Wno-unused-parameter \
    -o osqa src/main.cpp"
#echo
#echo $CMD
$CMD
ls -la --color osqa
