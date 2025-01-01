#!/bin/sh
set -e
cd $(dirname "$0")

cd ..

openFPGALoader impl/pnr/riscv.fs
