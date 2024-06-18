#!/bin/bash
set -e
cd $(dirname "$0")

openFPGALoader -b tangnano9k -f impl/pnr/riscv.fs
