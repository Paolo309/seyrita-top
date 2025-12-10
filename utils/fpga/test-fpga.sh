#!/bin/bash

WORKDIR="~/gitlab-ci"
BOARD_CLASS=vcu128
# TODO set as CI variables?
REMOTE_HOST=boardberg.ee.ethz.ch
REMOTE_USER=msc25h20

run_remote_command() {
    ssh $REMOTE_USER@$REMOTE_HOST "$1"
}

################
# BOOK AND RUN #
################

# book-and-run.sh returns 0 if successful, 254 if no board available, 253 if booking fails
status=254
while [ $status -eq 254 ]; do
    echo "Booking and running FPGA board of class $BOARD_CLASS ..."
    result=$(run_remote_command "bash -lc 'bash -s $WORKDIR $BOARD_CLASS'" < utils/fpga/book-and-run.sh)
    status=$?

    # no free board available
    if [ $status -eq 254 ]; then
        echo "$result"
        echo "Retrying in 5 minutes ..."
        sleep 5
    fi
done

if [ $status -ne 0 ]; then
    echo "$result"
    exit $status
fi

BOARD=$(echo "$result" | grep "BOARD: " | awk '{print $2}')
TCP_PORT=$(echo "$result" | grep "TCP: " | awk '{print $2}')
GDB_PORT=$(echo "$result" | grep "GDB: " | awk '{print $2}')

echo "[OK] Booked board $BOARD"
echo "Ports:"
echo "  - TCP: $TCP_PORT"
echo "  - GDB: $GDB_PORT"

###################
# FLASH AND RESET #
###################

echo "Programming bistream ..."
make chim-xilinx-program-$BOARD_CLASS CHIM_XILINX_HWS_URL=$REMOTE_HOST:$TCP_PORT

echo "Sending reset ..."
make chim-xilinx-reset-$BOARD_CLASS CHIM_XILINX_HWS_URL=$REMOTE_HOST:$TCP_PORT

##################################
# PREPARE GDB AND LAUNCH OPENOCD #
###################################

# XXX use a specific .gdbinit for CI
cp "$CHISDK_ROOT/.gdbinit" .
# sed -i "s/target extended-remote localhost:3333/target extended-remote $REMOTE_HOST:$GDB_PORT/" .gdbinit
sed -i "s/target extended-remote localhost:3333/target extended-remote localhost:$GDB_PORT/" .gdbinit
printf "\noc\nload\ncontinue\nquit\n" >> .gdbinit

echo "[DEBUG]"
cat ".gdbinit"

scp .gdbinit $REMOTE_USER@$REMOTE_HOST:$WORKDIR/
scp utils/fpga/openocd.*.tcl $REMOTE_USER@$REMOTE_HOST:$WORKDIR/
scp $CHISDK_ROOT/build-ASIC/bin/test_mxita_app $REMOTE_USER@$REMOTE_HOST:$WORKDIR/

OPENOCD_PID=$(run_remote_command "sh -c 'cd $WORKDIR && nohup openocd -f $REMOTE_USER-$BOARD-openocd.tcl -f openocd.$BOARD_CLASS.tcl >/dev/null 2>&1 & echo \$!'")
echo "Started OpenOCD with PID $OPENOCD_PID"

# to be sure OpenOCD is ready
sleep 2

################
# TEST ON FPGA #
################

echo "Starting FPGA tests ..."
run_remote_command "cd $WORKDIR && gdb-multiarch -iex 'set auto-load safe-path /' test_mxita_app" | tee gdb_output.log

# TODO add minicon process, writing output on a transcript to show at the end
# TODO add timeout to avoid hanging forever if it ever happens

############
# CLEAN UP #
############

echo "Killing OpenOCD with PID $OPENOCD_PID"
run_remote_command "kill $OPENOCD_PID"

rm -rf $WORKDIR/*

echo "Releasing board $BOARD ..."
run_remote_command "bash -lc 'fpga release -b $BOARD'"

RETURN_VALUE=$(cat gdb_output.log | grep "\[GDB\] Return Value:" | tail -n 1 | awk '{print $5}')

if [ -z "$RETURN_VALUE" ]; then
    echo "Error: no return value found"
    exit 200
fi

RETURN_VALUE="${RETURN_VALUE:1:-1}"
echo "Test application returned value: $RETURN_VALUE"

if ! [[ "$RETURN_VALUE" =~ ^-?[0-9]+$ ]]; then
    echo "Error: invalid return value"
    exit 201
fi

echo ""
if [ "$RETURN_VALUE" -eq 0 ]; then
    echo "PASS!"
else
    echo "FAIL :("
fi

exit $RETURN_VALUE
