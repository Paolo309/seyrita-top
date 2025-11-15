#!/bin/bash

if [ -z "$1" ]; then
    echo "Error: No remote specified."
    echo "Usage: ./connect-gdb.sh <remote> <executable>"
    echo "Example: ./connect-gdb.sh localhost:3333 ./build/my_program.elf"
    exit 1
fi

REMOTE=$1
EXECUTABLE=$(realpath "$2")
GDB_SCRIPT="run-fpga.gdb"

echo "Connecting to $REMOTE ..."

riscv -riscv64-gcc-11.2.0 riscv64-unknown-elf-gdb -batch \
    -ex "set \$remote = \"$REMOTE\"" \
    -x "$GDB_SCRIPT" \
    $EXECUTABLE

