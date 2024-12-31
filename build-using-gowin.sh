#!/bin/sh
set -e
cd $(dirname "$0")

./configuration-apply.py

gw_sh << EOF | grep -E 'WARN|ERROR'
open_project riscv.gprj
run all
EOF

