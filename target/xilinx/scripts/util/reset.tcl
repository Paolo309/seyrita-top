# Copyright 2018 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Paolo Galfano <paologalfano99@gmail.com>

# Connect to already programmed FPGA, load probes (ILAs/VIO), reset and exit

set xilinx_root [file dirname [file dirname [file dirname [file normalize [info script]]]]]
source -quiet ${xilinx_root}/scripts/util/connect.tcl

rst

quit
