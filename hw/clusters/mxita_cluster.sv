// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

`include "axi/assign.svh"
`include "axi/typedef.svh"
`include "tcdm_interface/typedef.svh"

module mxita_cluster
  import chimera_pkg::*;
  import cheshire_pkg::*;
#(
  parameter chimera_cfg_t Cfg = '0,

  parameter int unsigned NrCores = 9,

  parameter type narrow_in_req_t   = logic,
  parameter type narrow_in_resp_t  = logic,
  parameter type narrow_out_req_t  = logic,
  parameter type narrow_out_resp_t = logic,
  parameter type wide_out_req_t    = logic,
  parameter type wide_out_resp_t   = logic
) (
  input  logic                                        soc_clk_i,
  input  logic                                        clu_clk_i,
  input  logic                                        rst_ni,
  input  logic                                        widemem_bypass_i,
  //-----------------------------
  // Interrupt ports
  //-----------------------------
  input  logic             [             NrCores-1:0] debug_req_i,
  input  logic             [             NrCores-1:0] meip_i,
  input  logic             [             NrCores-1:0] mtip_i,
  input  logic             [             NrCores-1:0] msip_i,
  //-----------------------------
  // Cluster base addressing
  //-----------------------------
  input  logic             [                     9:0] hart_base_id_i,
  input  logic             [Cfg.ChsCfg.AddrWidth-1:0] cluster_base_addr_i,
  input  logic             [                    31:0] boot_addr_i,
  //-----------------------------
  // Narrow AXI ports
  //-----------------------------
  input  narrow_in_req_t                              narrow_in_req_i,
  output narrow_in_resp_t                             narrow_in_resp_o,
  output narrow_out_req_t  [                     1:0] narrow_out_req_o,
  input  narrow_out_resp_t [                     1:0] narrow_out_resp_i,
  //-----------------------------
  //Wide AXI ports
  //-----------------------------
  output wide_out_req_t                               wide_out_req_o,
  input  wide_out_resp_t                              wide_out_resp_i
  // input  snitch_cluster_pkg::wide_in_req_t                      cluster_wide_in_req_i,
  // output snitch_cluster_pkg::wide_in_resp_t                     cluster_wide_in_resp_o
);

  localparam int WideDataWidth = $bits(wide_out_req_o.w.data);

  localparam int WideMasterIdWidth = $bits(wide_out_req_o.aw.id);
  localparam int WideSlaveIdWidth = WideMasterIdWidth + $clog2(Cfg.ChsCfg.AxiExtNumWideMst) - 1;

  localparam int NarrowSlaveIdWidth = $bits(narrow_in_req_i.aw.id);
  localparam int NarrowMasterIdWidth = $bits(narrow_out_req_o[0].aw.id);

  typedef logic [Cfg.ChsCfg.AddrWidth-1:0] axi_addr_t;
  typedef logic [Cfg.ChsCfg.AxiUserWidth-1:0] axi_user_t;

  typedef logic [Cfg.ChsCfg.AxiDataWidth-1:0] axi_soc_data_narrow_t;
  typedef logic [Cfg.ChsCfg.AxiDataWidth/8-1:0] axi_soc_strb_narrow_t;

  typedef logic [ClusterDataWidth-1:0] axi_cluster_data_narrow_t;
  typedef logic [ClusterDataWidth/8-1:0] axi_cluster_strb_narrow_t;

  typedef logic [WideDataWidth-1:0] axi_cluster_data_wide_t;
  typedef logic [WideDataWidth/8-1:0] axi_cluster_strb_wide_t;

  typedef logic [ClusterNarrowAxiMstIdWidth-1:0] axi_cluster_mst_id_width_narrow_t;
  typedef logic [ClusterNarrowAxiMstIdWidth-1+2:0] axi_cluster_slv_id_width_narrow_t;

  typedef logic [NarrowMasterIdWidth-1:0] axi_soc_mst_id_width_narrow_t;
  typedef logic [NarrowSlaveIdWidth-1:0] axi_soc_slv_id_width_narrow_t;

  typedef logic [WideMasterIdWidth-1:0] axi_mst_id_width_wide_t;
  typedef logic [WideMasterIdWidth-1+2:0] axi_slv_id_width_wide_t;

  `AXI_TYPEDEF_ALL(axi_cluster_out_wide, axi_addr_t, axi_slv_id_width_wide_t,
                   axi_cluster_data_wide_t, axi_cluster_strb_wide_t, axi_user_t)
  `AXI_TYPEDEF_ALL(axi_cluster_in_wide, axi_addr_t, axi_mst_id_width_wide_t,
                   axi_cluster_data_wide_t, axi_cluster_strb_wide_t, axi_user_t)

  `AXI_TYPEDEF_ALL(axi_soc_out_narrow, axi_addr_t, axi_soc_slv_id_width_narrow_t,
                   axi_soc_data_narrow_t, axi_soc_strb_narrow_t, axi_user_t)
  `AXI_TYPEDEF_ALL(axi_soc_in_narrow, axi_addr_t, axi_soc_mst_id_width_narrow_t,
                   axi_soc_data_narrow_t, axi_soc_strb_narrow_t, axi_user_t)

  `AXI_TYPEDEF_ALL(axi_cluster_out_narrow, axi_addr_t, axi_cluster_slv_id_width_narrow_t,
                   axi_cluster_data_narrow_t, axi_cluster_strb_narrow_t, axi_user_t)
  `AXI_TYPEDEF_ALL(axi_cluster_in_narrow, axi_addr_t, axi_cluster_mst_id_width_narrow_t,
                   axi_cluster_data_narrow_t, axi_cluster_strb_narrow_t, axi_user_t)

  `AXI_TYPEDEF_ALL(axi_cluster_out_narrow_socIW, axi_addr_t, axi_soc_mst_id_width_narrow_t,
                   axi_cluster_data_narrow_t, axi_cluster_strb_narrow_t, axi_user_t)
  `AXI_TYPEDEF_ALL(axi_cluster_in_narrow_socIW, axi_addr_t, axi_soc_slv_id_width_narrow_t,
                   axi_cluster_data_narrow_t, axi_cluster_strb_narrow_t, axi_user_t)

  // Cluster-side in- and out- narrow ports used in chimera adapter
  axi_cluster_in_narrow_req_t   clu_axi_adapter_slv_req;
  axi_cluster_in_narrow_resp_t  clu_axi_adapter_slv_resp;
  axi_cluster_out_narrow_req_t  clu_axi_adapter_mst_req;
  axi_cluster_out_narrow_resp_t clu_axi_adapter_mst_resp;

  // Cluster-side in- and out- narrow ports used in narrow adapter
  axi_cluster_in_narrow_socIW_req_t         clu_axi_narrow_slv_req;
  axi_cluster_in_narrow_socIW_resp_t        clu_axi_narrow_slv_rsp;
  axi_cluster_out_narrow_socIW_req_t  [1:0] clu_axi_narrow_mst_req;
  axi_cluster_out_narrow_socIW_resp_t [1:0] clu_axi_narrow_mst_rsp;

  // Cluster-side out wide ports
  axi_cluster_out_wide_req_t    clu_axi_wide_mst_req;
  axi_cluster_out_wide_resp_t   clu_axi_wide_mst_resp;
 

  if (ClusterDataWidth != Cfg.ChsCfg.AxiDataWidth) begin : gen_narrow_adapter
    narrow_adapter #(
      .narrow_in_req_t  (axi_soc_out_narrow_req_t),
      .narrow_in_resp_t (axi_soc_out_narrow_resp_t),
      .narrow_out_req_t (axi_soc_in_narrow_req_t),
      .narrow_out_resp_t(axi_soc_in_narrow_resp_t),

      .clu_narrow_in_req_t  (axi_cluster_in_narrow_socIW_req_t),
      .clu_narrow_in_resp_t (axi_cluster_in_narrow_socIW_resp_t),
      .clu_narrow_out_req_t (axi_cluster_out_narrow_socIW_req_t),
      .clu_narrow_out_resp_t(axi_cluster_out_narrow_socIW_resp_t),

      .MstPorts(2),
      .SlvPorts(1)

    ) i_cluster_narrow_adapter (
      .soc_clk_i(soc_clk_i),
      .rst_ni,

      // SoC side narrow.
      .narrow_in_req_i  (narrow_in_req_i),   // <- SoC
      .narrow_in_resp_o (narrow_in_resp_o),  // -> SoC
      .narrow_out_req_o (narrow_out_req_o),  // -> SoC
      .narrow_out_resp_i(narrow_out_resp_i), // <- SoC

      // Cluster side narrow
      .clu_narrow_in_req_o  (clu_axi_narrow_slv_req),  // -> Chimera adapter
      .clu_narrow_in_resp_i (clu_axi_narrow_slv_rsp),  // <- Chimera adapter
      .clu_narrow_out_req_i (clu_axi_narrow_mst_req),  // <- Chimera adapter
      .clu_narrow_out_resp_o(clu_axi_narrow_mst_rsp)   // -> Chimera adapter

    );

  end else begin : gen_skip_narrow_adapter  // if (ClusterDataWidth != Cfg.AxiDataWidth)
    assign clu_axi_narrow_slv_req = narrow_in_req_i;
    assign narrow_in_resp_o       = clu_axi_narrow_slv_rsp;
    assign narrow_out_req_o       = clu_axi_narrow_mst_req;
    assign clu_axi_narrow_mst_rsp = narrow_out_resp_i;

  end

  chimera_cluster_adapter #(
    .WidePassThroughRegionStart(Cfg.MemIslRegionStart),
    .WidePassThroughRegionEnd  (Cfg.MemIslRegionEnd),

    .narrow_in_req_t  (axi_cluster_in_narrow_socIW_req_t),
    .narrow_in_resp_t (axi_cluster_in_narrow_socIW_resp_t),
    .narrow_out_req_t (axi_cluster_out_narrow_socIW_req_t),
    .narrow_out_resp_t(axi_cluster_out_narrow_socIW_resp_t),

    .clu_narrow_in_req_t  (axi_cluster_in_narrow_req_t),
    .clu_narrow_in_resp_t (axi_cluster_in_narrow_resp_t),
    .clu_narrow_out_req_t (axi_cluster_out_narrow_req_t),
    .clu_narrow_out_resp_t(axi_cluster_out_narrow_resp_t),

    .wide_out_req_t (wide_out_req_t),
    .wide_out_resp_t(wide_out_resp_t),

    .clu_wide_out_req_t (axi_cluster_out_wide_req_t),
    .clu_wide_out_resp_t(axi_cluster_out_wide_resp_t)

  ) i_cluster_axi_adapter (
    .soc_clk_i(soc_clk_i),
    .clu_clk_i(clu_clk_i),
    .rst_ni,

    // SoC side narrow (narrow adapter side)
    .narrow_in_req_i  (clu_axi_narrow_slv_req),  // <- narrow adapter
    .narrow_in_resp_o (clu_axi_narrow_slv_rsp),  // -> narrow adapter
    .narrow_out_req_o (clu_axi_narrow_mst_req),  // -> narrow adapter
    .narrow_out_resp_i(clu_axi_narrow_mst_rsp),  // <- narrow adapter

    // Cluster side narrow
    .clu_narrow_in_req_o  (clu_axi_adapter_slv_req),   // -> cluster
    .clu_narrow_in_resp_i (clu_axi_adapter_slv_resp),  // <- cluster
    .clu_narrow_out_req_i (clu_axi_adapter_mst_req),   // <- cluster
    .clu_narrow_out_resp_o(clu_axi_adapter_mst_resp),  // -> cluster

    // SoC side wide
    .wide_out_req_o (wide_out_req_o),  // -> SoC
    .wide_out_resp_i(wide_out_resp_i), // <- SoC 

    // Cluster side wide
    .clu_wide_out_req_i (clu_axi_wide_mst_req),  // <- cluster
    .clu_wide_out_resp_o(clu_axi_wide_mst_resp), // -> cluster

    .wide_mem_bypass_mode_i(widemem_bypass_i)
  );

  typedef struct packed {
    logic [2:0] ema;
    logic [1:0] emaw;
    logic [0:0] emas;
  } sram_cfg_t;

  typedef struct packed {
    sram_cfg_t icache_tag;
    sram_cfg_t icache_data;
    sram_cfg_t tcdm;
  } sram_cfgs_t;

  localparam int unsigned NumIntOutstandingLoads[NrCores] = '{NrCores{32'h1}};
  localparam int unsigned NumIntOutstandingMem[NrCores] = '{NrCores{32'h4}};

  typedef logic [WideDataWidth-1:0] data_dma_t;
  typedef logic [WideDataWidth/8-1:0] strb_dma_t;
  typedef logic [TcdmAddrWidth-1:0] tcdm_addr_t;
  `TCDM_TYPEDEF_ALL(tcdm_dma, tcdm_addr_t, data_dma_t, strb_dma_t, logic)

  axi_cluster_out_narrow_req_t  cluster_narrow_ext_req;
  axi_cluster_out_narrow_resp_t cluster_narrow_ext_rsp;
  tcdm_dma_req_t                cluster_tcdm_ext_req;
  tcdm_dma_rsp_t                cluster_tcdm_ext_rsp;

  localparam int unsigned HWPECtrlAddrWidth = 32;
  localparam int unsigned HWPECtrlDataWidth = 32;
  typedef logic [HWPECtrlAddrWidth-1:0] addr_hwpe_ctrl_t;
  typedef logic [HWPECtrlDataWidth-1:0] data_hwpe_ctrl_t;
  typedef logic [3:0] strb_hwpe_ctrl_t;
  typedef logic [ClusterNarrowAxiMstIdWidth+2-1:0] narrow_out_id_t;

  // TODO remove snitch_cluster_pkg::narrow_out_id_t with Chimera defined one
  `AXI_TYPEDEF_ALL(cluster_narrow_out_dw_conv, axi_addr_t,
                   narrow_out_id_t, data_hwpe_ctrl_t, strb_hwpe_ctrl_t,
                   axi_user_t)

  cluster_narrow_out_dw_conv_req_t cluster_narrow_out_dw_conv_req, cluster_narrow_out_cut_req;
  cluster_narrow_out_dw_conv_resp_t cluster_narrow_out_dw_conv_rsp, cluster_narrow_out_cut_rsp;

  `TCDM_TYPEDEF_ALL(hwpectrl, addr_hwpe_ctrl_t, data_hwpe_ctrl_t, strb_hwpe_ctrl_t, axi_user_t)

  hwpectrl_req_t               hwpectrl_req;
  hwpectrl_rsp_t               hwpectrl_rsp;

  logic          [NrCores-1:0] mxip;
  logic                        hwpe_clk_en;

  function automatic snitch_pma_pkg::rule_t [snitch_pma_pkg::NrMaxRules-1:0] get_cached_regions();
    automatic snitch_pma_pkg::rule_t [snitch_pma_pkg::NrMaxRules-1:0] cached_regions;
    cached_regions = '{default: '0};
    cached_regions[0] = '{base: HyperbusRegionStart, mask: 48'hffff_1000_0000}; // Hyperbus (256 MiB)
    cached_regions[1] = '{base: MemIslRegionStart, mask: 48'hffff_fff8_0000}; // Memory Island ( 512 KiB)
    return cached_regions;
  endfunction

  localparam snitch_pma_pkg::snitch_pma_t SnitchPMACfg = '{
      NrCachedRegionRules: 2,
      CachedRegion: get_cached_regions(),
      default: 0
  };

  snitch_cluster #(
    .PhysicalAddrWidth(Cfg.ChsCfg.AddrWidth),
    .NarrowDataWidth  (ClusterDataWidth),
    .WideDataWidth    (WideDataWidth),
    .NarrowIdWidthIn  (ClusterNarrowAxiMstIdWidth),
    .WideIdWidthIn    (WideMasterIdWidth),
    .NarrowUserWidth  (Cfg.ChsCfg.AxiUserWidth),
    .WideUserWidth    (Cfg.ChsCfg.AxiUserWidth),

    .narrow_in_req_t (axi_cluster_in_narrow_req_t),
    .narrow_in_resp_t(axi_cluster_in_narrow_resp_t),
    .narrow_out_req_t (axi_cluster_out_narrow_req_t),
    .narrow_out_resp_t(axi_cluster_out_narrow_resp_t),
    .wide_out_req_t   (axi_cluster_out_wide_req_t),
    .wide_out_resp_t  (axi_cluster_out_wide_resp_t),
    .wide_in_req_t   (axi_cluster_in_wide_req_t),
    .wide_in_resp_t  (axi_cluster_in_wide_resp_t),
    .tcdm_dma_req_t   (tcdm_dma_req_t),
    .tcdm_dma_rsp_t   (tcdm_dma_rsp_t),

    .BootAddr        (SnitchBootROMRegionStart),
    .AliasRegionEnable(1),
    .AliasRegionBase(48'h18000000), // TODO move to config
    .SnitchPMACfg     (SnitchPMACfg),
    .IntBootromEnable(0),

    .NrHives(1),
    .NrCores(NrCores),
    .TCDMDepth(1024),
    .ZeroMemorySize(64),
    // .ExtMemorySize (0), // not set in Chimera (no ext memory?) // TODO check in old snitch
    .ClusterPeriphSize(64),
    .NrBanks(16),
    .NrHyperBanks(1),
    .DMANumAxInFlight(3),
    .DMAReqFifoDepth(3),
    .ICacheLineWidth('{256}),
    .ICacheLineCount('{16}),
    .ICacheWays('{2}),
    .VMSupport(0),
    .EnableDMAMulticast(0),  // not set in Chimera (default is zero), but set to 1 by mxita wrapper
    .Xdma({1'b1, {(NrCores - 1) {1'b0}}}),

    .NumIntOutstandingLoads(NumIntOutstandingLoads),
    .NumIntOutstandingMem  (NumIntOutstandingMem),

    .RegisterOffloadReq(1),
    .RegisterOffloadRsp(1),
    .RegisterCoreReq   (1),
    .RegisterCoreRsp   (1),

    .sram_cfg_t (sram_cfg_t),
    .sram_cfgs_t(sram_cfgs_t),

    .RegisterExtWide  ('0),
    .RegisterExtNarrow('0)
  ) i_test_cluster (

    .clk_i          (clu_clk_i),
    .clk_d2_bypass_i('0),
    .rst_ni,

    .debug_req_i(debug_req_i),
    .meip_i     (meip_i),
    .mtip_i     (mtip_i),
    .msip_i     (msip_i),
    .mxip_i     (mxip),         // TODO added in new snitch: CHECK

    .hart_base_id_i     (hart_base_id_i),
    .cluster_base_addr_i(cluster_base_addr_i),
    .sram_cfgs_i        ('0),

    .narrow_in_req_i  (clu_axi_adapter_slv_req),   // <- chimera adapter
    .narrow_in_resp_o (clu_axi_adapter_slv_resp),  // -> chimera adapter
    .narrow_out_req_o (clu_axi_adapter_mst_req),   // -> chimera adapter
    .narrow_out_resp_i(clu_axi_adapter_mst_resp),  // <- chimera adapter

    .wide_in_req_i    ('0),
    .wide_in_resp_o   (),
    .wide_out_req_o   (clu_axi_wide_mst_req),      // -> chimera adapter
    .wide_out_resp_i  (clu_axi_wide_mst_resp),     // <- chimera adapter

    .narrow_ext_req_o  (cluster_narrow_ext_req), // -> AXI DW converter -> AXI cut -> AXI to TCDM -> HWPE
    .narrow_ext_resp_i (cluster_narrow_ext_rsp), // -> AXI DW converter -> AXI cut -> AXI to TCDM -> HWPE
    .tcdm_ext_req_i(cluster_tcdm_ext_req),  // -> HWPE
    .tcdm_ext_resp_o(cluster_tcdm_ext_rsp),

    .hwpe_clk_en_o    (hwpe_clk_en)
  );


  // Convert narrow AXI's 64 bit DW down to 32
  axi_dw_converter #(
    .AxiMaxReads        (1),
    .AxiSlvPortDataWidth(ClusterDataWidth),
    .AxiMstPortDataWidth(HWPECtrlDataWidth),
    .AxiAddrWidth       (Cfg.ChsCfg.AxiDataWidth),
    .AxiIdWidth         (ClusterNarrowAxiMstIdWidth+2),
    .aw_chan_t          (axi_cluster_out_narrow_aw_chan_t),
    .mst_w_chan_t       (cluster_narrow_out_dw_conv_w_chan_t),
    .slv_w_chan_t       (axi_cluster_out_narrow_w_chan_t),
    .b_chan_t           (axi_cluster_out_narrow_b_chan_t),
    .ar_chan_t          (axi_cluster_out_narrow_ar_chan_t),
    .mst_r_chan_t       (cluster_narrow_out_dw_conv_r_chan_t),
    .slv_r_chan_t       (axi_cluster_out_narrow_r_chan_t),
    .axi_mst_req_t      (cluster_narrow_out_dw_conv_req_t),
    .axi_mst_resp_t     (cluster_narrow_out_dw_conv_resp_t),
    .axi_slv_req_t      (axi_cluster_out_narrow_req_t),
    .axi_slv_resp_t     (axi_cluster_out_narrow_resp_t)
  ) i_axi_dw_hwpe (
    .clk_i     (clu_clk_i),
    .rst_ni    (rst_ni),
    .slv_req_i (cluster_narrow_ext_req),
    .slv_resp_o(cluster_narrow_ext_rsp),
    .mst_req_o (cluster_narrow_out_dw_conv_req),
    .mst_resp_i(cluster_narrow_out_dw_conv_rsp)
  );

  axi_cut #(
    .Bypass    (0),
    .aw_chan_t (cluster_narrow_out_dw_conv_aw_chan_t), // TODO compare with mxita
    .w_chan_t  (cluster_narrow_out_dw_conv_w_chan_t),
    .b_chan_t  (cluster_narrow_out_dw_conv_b_chan_t), // TODO compare with mxita
    .ar_chan_t (cluster_narrow_out_dw_conv_ar_chan_t), // TODO compare with mxita
    .r_chan_t  (cluster_narrow_out_dw_conv_r_chan_t),
    .axi_req_t (cluster_narrow_out_dw_conv_req_t),
    .axi_resp_t(cluster_narrow_out_dw_conv_resp_t)
  ) i_cut_ext_narrow_slv (
    .clk_i     (clu_clk_i),
    .rst_ni    (rst_ni),
    .slv_req_i (cluster_narrow_out_dw_conv_req),
    .slv_resp_o(cluster_narrow_out_dw_conv_rsp),
    .mst_req_o (cluster_narrow_out_cut_req),
    .mst_resp_i(cluster_narrow_out_cut_rsp)
  );

  axi_to_tcdm #(
    .user_t (axi_user_t),
    .axi_req_t (cluster_narrow_out_dw_conv_req_t),
    .axi_rsp_t (cluster_narrow_out_dw_conv_resp_t),
    .tcdm_req_t(hwpectrl_req_t),
    .tcdm_rsp_t(hwpectrl_rsp_t),
    .IdWidth   (ClusterNarrowAxiMstIdWidth+2),
    .AddrWidth (HWPECtrlAddrWidth),
    .DataWidth (HWPECtrlDataWidth)
  ) i_axi_to_hwpe_ctrl (
    .clk_i     (clu_clk_i),
    .rst_ni    (rst_ni),
    .axi_req_i (cluster_narrow_out_cut_req),
    .axi_rsp_o (cluster_narrow_out_cut_rsp),
    .tcdm_req_o(hwpectrl_req),
    .tcdm_rsp_i(hwpectrl_rsp)
  );

  logic [9:0] hwpe_cluster_user;
  assign hwpe_cluster_user = (hart_base_id_i / NrCores) + (hart_base_id_i % NrCores) + 1'b1;

  snitch_hwpe_subsystem #(
    .tcdm_req_t   (tcdm_dma_req_t),
    .tcdm_rsp_t   (tcdm_dma_rsp_t),
    .periph_req_t (hwpectrl_req_t),
    .periph_rsp_t (hwpectrl_rsp_t),
    .HwpeDataWidth(WideDataWidth),
    .IdWidth      (ClusterNarrowAxiMstIdWidth+2),
    .NrCores      (NrCores),
    .TCDMDataWidth(ClusterDataWidth)
  ) i_snitch_hwpe_subsystem (
    .clk_i          (clu_clk_i),
    .rst_ni         (rst_ni),
    .test_mode_i    (1'b0),
    .hwpe_clk_en_i  (hwpe_clk_en),
    .tcdm_req_o     (cluster_tcdm_ext_req),
    .tcdm_rsp_i     (cluster_tcdm_ext_rsp),
    .hwpe_ctrl_req_i(hwpectrl_req),
    .hwpe_ctrl_rsp_o(hwpectrl_rsp),
    .hwpe_evt_o     (mxip),
    .cluster_user_i  (hwpe_cluster_user[ClusterNarrowAxiMstIdWidth+2-1:0])
  );

  //////////////////////////
  // Clock Gating & Reset //
  //////////////////////////

  /*
  tc_clk_gating i_tc_clk_gating_cluster (
    .clk_i,
    .en_i     (tile_clk_en_i),
    .test_en_i(clk_rst_bypass_i),
    .clk_o    (tile_clk)
  );

`ifdef TARGET_XILINX
  // Using clk cells makes Vivado flag the reset as a clock tree
  assign tile_rst_n = (clk_rst_bypass_i) ? rst_ni : tile_rst_ni;
`else
  tc_clk_mux2 i_tc_reset_mux (
    .clk0_i   (tile_rst_ni),
    .clk1_i   (rst_ni),
    .clk_sel_i(clk_rst_bypass_i),
    .clk_o    (tile_rst_n)
  );
`endif
*/


endmodule
