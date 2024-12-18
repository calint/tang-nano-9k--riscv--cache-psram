#!/bin/sh
#
# builds console version
#
# note: assumes running in visual studio code terminal window
#       regarding encoding of backspace and delete
#
set -e
cd $(dirname "$0")

BIN=console_application

g++ -std=c++23 \
    -O3 \
    -g \
    -Wall -Wextra -pedantic \
    -Wconversion \
    -Wshadow \
    -Wno-unused-function \
    -Wno-unused-parameter \
    -o $BIN \
    src/console_application.cpp

ls -l $BIN

