// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

// Temporary module just to enable synthesis: not tested, likely doesn't work

module chimera_top_xilinx (
    input  logic sys_clk_p,
    input  logic sys_clk_n,

    input  logic sys_resetn,

    // JTAG
    input  logic jtag_tck_i,
    input  logic jtag_tms_i,
    input  logic jtag_tdi_i,
    output logic jtag_tdo_o,
    input  logic jtag_trst_ni,

    // UART
    output logic uart_tx_o,
    input  logic uart_rx_i
);

    //================================================================
    // Clock Generation
    //================================================================

    wire sys_clk;
    wire soc_clk;
    wire clu_clk;
    wire locked;

    IBUFDS #(
        .IBUF_LOW_PWR ("FALSE")
    ) i_bufds_sys_clk (
        .I  ( sys_clk_p ),
        .IB ( sys_clk_n ),
        .O  ( sys_clk   )
    );

    clkwiz i_clkwiz (
        .clk_in1 ( sys_clk ),
        .reset   ( ~sys_resetn ),
        .locked  ( locked ),
        .clk_50( soc_clk ),
        .clk_48( clu_clk ) // TODO probably should be connected to the same clock?
    );

    //================================================================
    // VIO (Virtual Input/Output) Reset
    //================================================================
    wire vio_reset;

    vio i_vio (
        .clk        ( soc_clk ),
        .probe_out0 ( vio_reset )
    );

    //================================================================
    // Reset
    //================================================================
    wire rst_n;

    rstgen i_rstgen (
        .clk_i        ( soc_clk ),
        .rst_ni       ( (sys_resetn & ~vio_reset) & locked ),
        .test_mode_i  ( 1'b0 ),
        .rst_no       ( rst_n ),
        .init_no      ( )
    );

    //================================================================
    // Chimera SoC
    //================================================================

    chimera_top_wrapper #(
        .SelectedCfg (2) // MXITA config
    ) i_chimera_soc (
        .soc_clk_i   ( soc_clk ),
        .clu_clk_i   ( clu_clk ),
        .rst_ni      ( rst_n ),
        .test_mode_i ( 1'b0 ),
        .boot_mode_i ( 2'b00 ),
        .rtc_i       ( 1'b0 ),

        // JTAG
        .jtag_tck_i    ( jtag_tck_i ),
        .jtag_trst_ni  ( jtag_trst_ni ),
        .jtag_tms_i    ( jtag_tms_i ),
        .jtag_tdi_i    ( jtag_tdi_i ),
        .jtag_tdo_o    ( jtag_tdo_o ),
        .jtag_tdo_oe_o ( ),

        // UART
        .uart_tx_o ( uart_tx_o ),
        .uart_rx_i ( uart_rx_i ),

        // Not used for now
        .uart_rts_no   ( ),
        .uart_dtr_no   ( ),
        .uart_cts_ni   ( 1'b1 ),
        .uart_dsr_ni   ( 1'b1 ),
        .uart_dcd_ni   ( 1'b1 ),
        .uart_rin_ni   ( 1'b1 ),

        .i2c_sda_o     ( ), .i2c_sda_i     ( 1'b0 ), .i2c_sda_en_o  ( ),
        .i2c_scl_o     ( ), .i2c_scl_i     ( 1'b0 ), .i2c_scl_en_o  ( ),
        .spih_sck_o    ( ), .spih_sck_en_o ( ),
        .spih_csb_o    ( ), .spih_csb_en_o ( ),
        .spih_sd_o     ( ), .spih_sd_en_o  ( ),     .spih_sd_i     ( 4'b0 ),
        .gpio_i        ( 32'b0 ), .gpio_o        ( ), .gpio_en_o     ( ),
        .hyper_cs_no   ( ), .hyper_ck_o      ( ), .hyper_ck_no     ( ),
        .hyper_rwds_o  ( ), .hyper_rwds_i    ( '0 ), .hyper_rwds_oe_o ( ),
        .hyper_dq_i    ( '0 ), .hyper_dq_o      ( ), .hyper_dq_oe_o   ( ),
        .hyper_reset_no( ),
        .apb_rsp_i     ( '{pready: 1'b1, pslverr: 1'b0, prdata: '0} ),
        .apb_req_o     ( ),
        .pmu_rst_clusters_ni       ( '1 ),
        .pmu_clkgate_en_clusters_i ( '0 ),
        .pmu_iso_en_clusters_i     ( '0 ),
        .pmu_iso_ack_clusters_o    ( )
    );

endmodule