#!/bin/sh
set -e
cd $(dirname "$0")

./make.sh
openFPGALoader -b tangnano9k --verify --external-flash os.bin
