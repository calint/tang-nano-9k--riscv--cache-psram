#!/bin/sh
set -e
cd $(dirname "$0")

../configuration-apply.py
../qa/qa.sh
../os/make-and-test-all.sh
