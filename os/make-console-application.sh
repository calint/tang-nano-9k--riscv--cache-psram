#!/bin/sh
#
# builds console version of "os"
#
set -e
cd $(dirname "$0")

BIN=os

gcc -o $BIN -O0 -g -Wall -Wextra -pedantic \
    -Wconversion \
    -Wshadow \
    -Wno-unused-parameter \
    console-application.c

ls -l $BIN

./$BIN
