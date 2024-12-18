#!/bin/sh
#
# builds console version
#
# note: assumes running in visual studio code terminal window
#       regarding encoding of backspace and delete
#
# tools used:
#        g++: 14.2.1
#
set -e
cd $(dirname "$0")

BIN=console_application

g++ -std=c++23 \
    -O3 \
    -g \
    -fno-rtti \
    -fno-exceptions \
    -Wall -Wextra -Wpedantic \
    -Wconversion \
    -Wsign-conversion \
    -Wshadow \
    -Wno-unused-function \
    -Wno-unused-parameter \
    -o $BIN \
    src/console_application.cpp

ls -l $BIN

