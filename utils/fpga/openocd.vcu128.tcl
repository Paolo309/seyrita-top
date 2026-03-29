# OpenOCD script for Chimera through Digilent HS2 adapter.

adapter speed 8000
adapter driver ftdi
ftdi vid_pid 0x0403 0x6014
ftdi layout_init 0x00e8 0x60eb
ftdi channel 0
set irlen 5

source [file dirname [info script]]/openocd.common.tcl
