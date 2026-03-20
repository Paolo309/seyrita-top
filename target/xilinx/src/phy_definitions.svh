// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

`ifdef TARGET_VCU118
  `define USE_RESET
  `define USE_JTAG
  `define USE_DDR4
  `define USE_QSPI
  `define USE_STARTUPE3
  `define USE_VIO
`endif

`ifdef TARGET_VCU128
  `define USE_RESET
  `define USE_JTAG
  `define USE_JTAG_VDDGND
  `define USE_DDR4
  `define USE_QSPI
  `define USE_STARTUPE3
  `define USE_VIO
`endif

`define ila(__name, __signal)  \
  (* dont_touch = "yes" *) (* mark_debug = "true" *) logic [$bits(__signal)-1:0] __name; \
  assign __name = __signal;
