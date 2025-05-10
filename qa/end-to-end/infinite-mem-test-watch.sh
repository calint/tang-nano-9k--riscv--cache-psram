#!/bin/bash
#
# note: when script fails `cat` process might be active reading from TTY 
#  do `ps aux | grep cat` and terminate the process
#
set -e
cd $(dirname "$0")

watch "grep succeeded test.out | wc -l; grep FAILED test.out | wc -l"