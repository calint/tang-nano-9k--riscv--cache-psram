#!/bin/sh
set -e
cd $(dirname "$0")

cd ..

rm -rf impl/pnr/

./configuration-apply.py

gw_sh << EOF | grep -E 'WARN|ERROR|Bitstream generation completed'
open_project riscv.gprj
run all
EOF

ls -l impl/pnr/riscv.fs

