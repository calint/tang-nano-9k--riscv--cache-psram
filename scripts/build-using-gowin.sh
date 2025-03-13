#!/bin/sh
set -e
cd $(dirname "$0")

echo

# apply configuration
../configuration-apply.py

# override configuration
. ./configuration.sh

cd ..

# remove previous pnr
rm -rf impl/pnr/

echo

# build
gw_sh << EOF | grep -E 'WARN|ERROR|Bitstream generation completed'
open_project riscv.gprj
run all
EOF

# check result
if [ ! -f "$BITSTREAM_FILE" ]; then
    echo
    echo -e "\e[31mbuild failed. bitstream file '$BITSTREAM_FILE' not created.\e[0m"
    exit 1
fi

# check file size
FILE_SIZE=$(stat -c %s "$BITSTREAM_FILE")

echo -e "\e[32m"
echo "file: $BITSTREAM_FILE"
echo "size: $FILE_SIZE B"
echo " max: $BITSTREAM_FILE_MAX_SIZE_BYTES B"
echo -e "\e[0m"

grep -A 4 "2.3 Max Frequency Summary" impl/pnr/riscv.tr | tail -n 4

if [ "$FILE_SIZE" -gt "$BITSTREAM_FILE_MAX_SIZE_BYTES" ]; then
    echo -e "\e[31mfirmware size exceeds allocated flash storage.\e[0m"
    exit 1
fi
