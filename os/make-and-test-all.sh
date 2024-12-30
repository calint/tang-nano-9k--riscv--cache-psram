#!/bin/bash
set -e
cd $(dirname "$0")

echo " * build console application"
./make-console-application.sh
echo " * build fpga flash binary"
./make-fpga-flash-binary.sh
echo " * build emulator"
../emulator/make.sh

echo " * test console application"
qa-console/test.sh
echo " * test os.bin using emulator"
qa-emulator/test.sh
