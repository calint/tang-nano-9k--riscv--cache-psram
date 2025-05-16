#!/bin/sh
set -e
cd $(dirname "$0")

../configuration-apply.py
../qa/test.sh
../emulator/qa/test.sh
../os/make-and-test-all.sh
