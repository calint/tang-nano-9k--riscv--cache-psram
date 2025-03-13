#!/bin/sh
#
# tools used:
#        g++: 14.2.1
#
set -e
cd $(dirname "$0")

CMD="g++ -std=c++23 -O3 $@ -fno-rtti -fno-exceptions -Wfatal-errors -Werror -Wall -Wextra -Wpedantic \
    -Wconversion -Wsign-conversion -Wswitch-default -Wimplicit-fallthrough \
    -Wshadow -Wlogical-op -Wnon-virtual-dtor -Wcast-align -Woverloaded-virtual \
    -Wduplicated-cond -Wduplicated-branches -Wnull-dereference -Wuseless-cast \
    -Wdouble-promotion -Wmisleading-indentation -Wformat=2 \
    -o osqa src/main.cpp"
#echo
#echo $CMD
#echo
$CMD
ls -la --color osqa
