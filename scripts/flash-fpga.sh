#!/bin/sh
set -e
cd $(dirname "$0")

cd ..

openFPGALoader --write-flash impl/pnr/riscv.fs
