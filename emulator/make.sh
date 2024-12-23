#!/bin/bash
set -e
cd $(dirname "$0")

g++ -std=c++23 -o osqa -fno-rtti -fno-exceptions -Wfatal-errors -Werror -Wall -Wextra -Wpedantic -Wswitch-default -Wno-unused-parameter src/main.cpp
echo
ls -la --color osqa
echo
