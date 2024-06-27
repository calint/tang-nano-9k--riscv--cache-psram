#!/bin/sh
set -e
cd $(dirname "$0")

openFPGALoader --board tangnano9k impl/pnr/riscv.fs
