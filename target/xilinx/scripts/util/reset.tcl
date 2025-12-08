# Connect to already programmed FPGA, load probes (ILAs/VIO), reset and exit

set xilinx_root [file dirname [file dirname [file dirname [file normalize [info script]]]]]
source -quiet ${xilinx_root}/scripts/util/connect.tcl

rst

quit
