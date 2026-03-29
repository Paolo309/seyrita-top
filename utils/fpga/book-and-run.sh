#!/bin/bash

# This is supposed to run on boardberg

set -e

WORKDIR=$1
BOARD=$2

# usage: strip_ansi STRING
strip_ansi() {
    echo "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

free_board=$(fpga list -m | grep $BOARD | awk -F',' '$2 == "False" {print $1; exit}')

if [ -z "$free_board" ]; then
    echo "No free $BOARD boards available."
    exit 254
fi

result=$(fpga book -t 1h -b $free_board)

if [[ $result != *"INFO: Booked $free_board"* ]]; then
    echo "couldn't book the board. Output:"
    echo "$result"
    exit 253
fi

cd $WORKDIR
ports=$(fpga run -b $free_board)
ports=$(strip_ansi "$ports")

tcp_port=$(echo "$ports" | grep "TCP port" | awk -F': ' '{print $3}')
gdb_port=$(echo "$ports" | grep "OpenOCD GDB port" | awk -F': ' '{print $3}')

echo "BOARD: $free_board"
echo "TCP: $tcp_port"
echo "GDB: " $gdb_port
