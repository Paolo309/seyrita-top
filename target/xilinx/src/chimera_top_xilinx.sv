// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

// Temporary module just to enable synthesis: not tested, likely doesn't work

`include "phy_definitions.svh"

module chimera_top_xilinx (
    input  logic sys_clk_p,
    input  logic sys_clk_n,

    input  logic sys_reset,

    // JTAG
    input  logic jtag_tck_i,
    input  logic jtag_tms_i,
    input  logic jtag_tdi_i,
    output logic jtag_tdo_o,
    output logic jtag_vdd_o,
    output logic jtag_gnd_o,

    // UART
    output logic uart_tx_o,
    input  logic uart_rx_i
);

    //================================================================
    // Clock Generation
    //================================================================

    wire sys_clk;
    wire soc_clk;
    // wire clu_clk;

    IBUFDS #(
        .IBUF_LOW_PWR ("FALSE")
    ) i_bufds_sys_clk (
        .I  ( sys_clk_p ),
        .IB ( sys_clk_n ),
        .O  ( sys_clk   )
    );

    clkwiz i_clkwiz (
        .clk_in1 ( sys_clk ),
        .reset   ( '0 ),
        .locked  ( ),
        .clk_50  ( soc_clk ),
        .clk_48  ( ),
        .clk_20  ( ),
        .clk_10  ( )
    );


    //================================================================
    // VIO (Virtual Input/Output) Reset
    //================================================================
    wire vio_reset;
    wire sys_rst;

    vio i_vio (
        .clk        ( soc_clk ),
        .probe_out0 ( vio_reset )
    );

    assign sys_rst = sys_reset | vio_reset;
    `ila(sys_reset_btn, sys_reset)
    `ila(sys_rst_comb, sys_rst)

    //================================================================
    // Reset
    //================================================================
    wire rst_n;

    rstgen i_rstgen (
        .clk_i        ( soc_clk ),
        .rst_ni       ( ~sys_rst ),
        .test_mode_i  ( 1'b0 ),
        .rst_no       ( rst_n ),
        .init_no      ( )
    );

    `ila(rst_n_gen, rst_n)

    ////////////
    //  JTAG  //
    ////////////

    assign jtag_vdd_o = 1'b1;
    assign jtag_gnd_o = 1'b0;

    /////////////////////////
    // "RTC" Clock Divider //
    /////////////////////////
    logic rtc_clk_d, rtc_clk_q;
    logic [15:0] counter_d, counter_q;

    // Divide soc_clk (50 MHz) by 50 => 1 MHz RTC Clock
    always_comb begin
        counter_d = counter_q + 1;
        rtc_clk_d = rtc_clk_q;

        if(counter_q == 24) begin
            counter_d = '0;
            rtc_clk_d = ~rtc_clk_q;
        end
    end

    always_ff @(posedge soc_clk, negedge rst_n) begin
        if(~rst_n) begin
            counter_q <= '0;
            rtc_clk_q <= 0;
        end else begin
            counter_q <= counter_d;
            rtc_clk_q <= rtc_clk_d;
        end
    end

    // ILAs for JTAG

    `ila(jtag_tck, jtag_tck_i)
    `ila(jtag_tms, jtag_tms_i)
    `ila(jtag_tdi, jtag_tdi_i)
    `ila(jtag_tdo, jtag_tdo_o)

    //================================================================
    // Chimera SoC
    //================================================================

    chimera_top_wrapper #(
        .SelectedCfg (2) // MXITA config
    ) i_chimera_soc (
        .soc_clk_i   ( soc_clk ),
        .clu_clk_i   ( soc_clk ),
        .rst_ni      ( rst_n ),
        .test_mode_i ( 1'b0 ),
        .boot_mode_i ( 2'b00 ),
        .rtc_i       ( rtc_clk_q ),

        // JTAG
        .jtag_tck_i    ( jtag_tck ),
        .jtag_trst_ni  ( 1'b1 ),
        .jtag_tms_i    ( jtag_tms ),
        .jtag_tdi_i    ( jtag_tdi ),
        .jtag_tdo_o    ( jtag_tdo ),
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