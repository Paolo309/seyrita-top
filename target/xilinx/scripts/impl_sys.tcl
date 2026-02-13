# Copyright 2018 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Florian Zaruba <zarubaf@iis.ee.ethz.ch>
# Nils Wistoff <nwistoff@iis.ee.ethz.ch>
# Cyril Koenig <cykoenig@iis.ee.ethz.ch>
# Paul Scheffler <cykoenig@iis.ee.ethz.ch>
# Paolo Galfano <paologalfano99@gmail.com>

# Initialize implementation
set xilinx_root [file dirname [file dirname [file normalize [info script]]]]
source ${xilinx_root}/scripts/common.tcl
init_impl $xilinx_root $argc $argv

# Addtional args provide IPs
read_ip [exec realpath {*}[lrange $argv 2 end]]

# Load constraints
import_files -fileset constrs_1 -norecurse ${xilinx_root}/constraints/${proj}.xdc
import_files -fileset constrs_1 -norecurse ${xilinx_root}/constraints/${board}.xdc

# Load RTL sources
source ${xilinx_root}/scripts/add_sources.${board}.tcl

# Set top module
set_property top ${proj}_top_xilinx [current_fileset]
update_compile_order -fileset sources_1

# Set synthesis properties
# TODO: investigate resource-affordable retiming
set_property XPM_LIBRARIES XPM_MEMORY [current_project]
# XXX Should not be commented (although it might interfere with ILA)
# set_property strategy Flow_PerfOptimized_high [get_runs synth_1]

# TODO remove
# set_msg_config -id "Synth 8-524" -new_severity "ERROR"
# set_msg_config -id "Synth 8-*" -string -regexp {.*} -show_hierarchy true

# Elaborate and open design to explore all clocks
synth_design -rtl -name rtl_1 -verbose
# report_clocks -file ${project_root}/clocks.rpt

# Synthesis
launch_runs -jobs $num_jobs synth_1
wait_on_run synth_1
open_run synth_1

# Generate synthesis reports
gen_reports ${project_root}/reports.synth

# Instantiate debug core and ILAs
insert_ilas {soc_clk}

# Set implementation properties
# set_property strategy Performance_Explore [get_runs impl_1]
# # set_property strategy Performance_ExtraTimingOpt [get_runs impl_1]
# set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE SSI_SpreadLogic_high [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE SSI_SpreadSLLs [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE AggressiveExplore     [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]


# Floorplanning
# TODO move to board specific xdc

#-------------------------------------------------------
# create_pblock pblock_host
# resize_pblock pblock_host -add CLOCKREGION_X3Y4:CLOCKREGION_X7Y7
# add_cells_to_pblock pblock_host [get_cells [list i_chimera_soc/i_cheshire]]
# add_cells_to_pblock pblock_host [get_cells [list i_chimera_soc/i_memisland_domain]]

# set cluster0 [get_cells {i_chimera_soc/i_cluster_domain/gen_clusters[0].gen_cluster_mxita.i_mxita_cluster}]
# set cluster0_children [get_cells -hier -filter "PARENT == $cluster0"]
# # separate cluster adapters from the other modules
# set adapters0 [filter $cluster0_children {NAME =~ "*i_cluster_axi_adapter*" || NAME =~ "*i_cluster_narrow_adapter*"}]
# # set others0 [filter $cluster0_children {NAME !~ "*i_cluster_axi_adapter*" && NAME !~ "*i_cluster_narrow_adapter*"}]

# create_pblock pblock_i_cluster_0_domain
# resize_pblock pblock_i_cluster_0_domain -add SLR0:SLR0
# add_cells_to_pblock pblock_i_cluster_0_domain $cluster0
# remove_cells_from_pblock pblock_i_cluster_0_domain $adapters0

# create_pblock pblock_adapters0
# resize_pblock pblock_adapters0 -add CLOCKREGION_X0Y6:CLOCKREGION_X4Y7
# add_cells_to_pblock pblock_adapters0 $adapters0

# set cluster1 [get_cells {i_chimera_soc/i_cluster_domain/gen_clusters[1].gen_cluster_mxita.i_mxita_cluster}]
# set cluster1_children [get_cells -hier -filter "PARENT == $cluster1"]
# # separate cluster adapters from the other modules
# set adapters1 [filter $cluster1_children {NAME =~ "*i_cluster_axi_adapter*" || NAME =~ "*i_cluster_narrow_adapter*"}]
# # set others1 [filter $cluster1_children {NAME !~ "*i_cluster_axi_adapter*" && NAME !~ "*i_cluster_narrow_adapter*"}]

# create_pblock pblock_i_cluster_1_domain
# resize_pblock pblock_i_cluster_1_domain -add SLR2:SLR2
# add_cells_to_pblock pblock_i_cluster_1_domain $cluster1
# remove_cells_from_pblock pblock_i_cluster_1_domain $adapters1

# create_pblock pblock_adapters1
# resize_pblock pblock_adapters1 -add CLOCKREGION_X0Y4:CLOCKREGION_X4Y5
# add_cells_to_pblock pblock_adapters1 $adapters1
#-------------------------------------------------------

# # TODO try
# # set_property EXCLUDE_PLACEMENT true [get_pblocks pblock_i_cluster_0_domain]
# # set_property EXCLUDE_PLACEMENT true [get_pblocks pblock_i_cluster_1_domain]

# # set_property IS_SOFT true [get_pblocks pblock_i_cluster_0_domain]
# # set_property IS_SOFT true [get_pblocks pblock_i_cluster_1_domain]

# # Example:
# # add_cells_to_pblock pblock_host [get_cells -hier -filter {NAME =~ "i_chimera_soc/i_cheshire/*"}]

# write_xdc -force ${project_root}/constraints/floorplan_pblocks.xdc

# Implementation
launch_runs -jobs $num_jobs impl_1 -to_step write_bitstream
wait_on_run impl_1
open_run impl_1

# Generate implementation reports
gen_reports ${project_root}/reports.impl
# TODO uncomment
# set trep [report_timing_summary -no_header -no_detailed_paths -return_string]
# if { ![string match -nocase {*timing constraints are met*} $trep] } {
#     puts "Error: Timing constraints not met for ${proj} on ${board}."
#     return -code error
# }

# Copy out final bitstream
file mkdir ${xilinx_root}/out
file copy -force ${project_root}/${proj}.runs/impl_1/chimera_top_xilinx.bit \
    ${xilinx_root}/out/${proj}.${board}.bit
file copy -force ${project_root}/${proj}.runs/impl_1/chimera_top_xilinx.ltx \
    ${xilinx_root}/out/${proj}.${board}.ltx
