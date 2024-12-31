#!/bin/sh
set -e
cd $(dirname "$0")

openFPGALoader -b tangnano9k --verify --external-flash firmware.bin
