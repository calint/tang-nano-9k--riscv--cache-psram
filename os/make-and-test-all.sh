#!/bin/sh
set -e
cd $(dirname "$0")

echo " * build console application"
./make-console-application.sh
qa-console/test.sh

echo " * build fpga flash binary"
./make-fpga-flash-binary.sh
echo " * build emulator"
../emulator/make.sh
qa-emulator/test.sh
