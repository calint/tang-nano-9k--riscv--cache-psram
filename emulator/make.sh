#!/bin/bash
set -e
cd $(dirname "$0")

g++ -std=c++23 -fno-rtti -fno-exceptions -Wfatal-errors -Werror -Wall -Wextra -Wpedantic \
    -Wswitch-default -Wconversion \
    -Wno-unused-parameter \
    -o osqa src/main.cpp
echo
ls -la --color osqa
echo
