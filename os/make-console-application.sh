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
    -Os \
    -g \
    -fno-rtti \
    -fno-exceptions \
    -fno-toplevel-reorder \
    -Wfatal-errors \
    -Werror \
    -Wall -Wextra -Wpedantic \
    -Wshadow \
    -Wnon-virtual-dtor \
    -Wcast-align \
    -Woverloaded-virtual \
    -Wconversion \
    -Wsign-conversion \
    -Wmisleading-indentation \
    -Wduplicated-cond \
    -Wduplicated-branches \
    -Wlogical-op \
    -Wnull-dereference \
    -Wuseless-cast \
    -Wdouble-promotion \
    -Wformat=2 \
    -Wimplicit-fallthrough \
    -Wno-unused-function \
    -Wno-unused-parameter \
    -o $BIN \
    src/console_application.cpp

ls -l --color $BIN

