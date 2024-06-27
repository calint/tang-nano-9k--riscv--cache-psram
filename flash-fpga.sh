#!/bin/sh
set -e
cd $(dirname "$0")

openFPGALoader --board tangnano9k --write-flash impl/pnr/riscv.fs
