#!/bin/sh
#
# builds console version
#
set -e
cd $(dirname "$0")

BIN=console_application

g++ -std=c++23 \
    -O0 \
    -g \
    -Wall -Wextra -pedantic \
    -Wconversion \
    -Wshadow \
    -Wno-unused-function \
    -Wno-unused-parameter \
    -o $BIN \
    src/console_application.cpp

ls -l $BIN

