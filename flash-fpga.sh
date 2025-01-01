#!/bin/sh
set -e
cd $(dirname "$0")

openFPGALoader --write-flash impl/pnr/riscv.fs
