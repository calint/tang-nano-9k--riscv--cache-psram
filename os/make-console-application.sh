#!/bin/sh
#
# builds console version of "os"
#
set -e
cd $(dirname "$0")

BIN=os

g++ -o $BIN -O0 -g -Wall -Wextra -pedantic \
    -Wconversion \
    -Wshadow \
    -Wno-unused-parameter \
    console-application.cpp

ls -l $BIN

./$BIN
