#!/bin/sh
set -e
cd $(dirname "$0")

../qa/qa.sh
../os/make-and-test-all.sh
