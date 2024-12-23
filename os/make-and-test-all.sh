#!/bin/bash
set -e

echo " * build console application"
./make-console-application.sh
echo " * build fpga flash binary"
./make-fpga-flash-binary.sh
echo " * test console application"
qa-console/test.sh
echo " * test os.bin using emulator"
qa-emulator/test.sh
