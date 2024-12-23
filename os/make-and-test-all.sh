#!/bin/bash
set -e

./make-console-application.sh
./make-fpga-flash-binary.sh
qa-console/test.sh
qa-emulator/test.sh
