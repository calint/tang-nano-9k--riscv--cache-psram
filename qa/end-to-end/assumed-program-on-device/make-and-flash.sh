#!/bin/bash
set -e
cd $(dirname "$0")

./make.sh && 
openFPGALoader -b tangnano9k --external-flash os.bin
