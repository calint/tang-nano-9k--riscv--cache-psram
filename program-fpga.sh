#!/bin/sh
set -e
cd $(dirname "$0")

openFPGALoader impl/pnr/riscv.fs
