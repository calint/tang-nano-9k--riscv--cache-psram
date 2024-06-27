#!/bin/sh
#
# builds console version of "os"
#
set -e
cd $(dirname "$0")

BIN=os-console

g++ -std=c++23 \
    -O0 \
    -g \
    -Wall -Wextra -pedantic \
    -Wconversion \
    -Wshadow \
    -Wno-unused-function \
    -Wno-unused-parameter \
    -o $BIN \
    src/console-application.cpp

ls -l $BIN

