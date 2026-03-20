# Connect to already programmed FPGA and load probes (ILAs/VIO)
# Can be used to manually reset board via VIO probe

set vio_default vio_reset_1

# Open hardware target
set xilinx_root [file dirname [file dirname [file dirname [file normalize [info script]]]]]
source -quiet ${xilinx_root}/scripts/common.tcl
open_target $xilinx_root $argc $argv noprog

# Additional argument provides bitstream
set bit [lindex $argv 3]
set ltx [file rootname $bit].ltx

# Flash bitstream and refresh device (also load probes)
current_hw_device $hw_device
if {[file exists $ltx]} {
    set_property PROBES.FILE $ltx $hw_device
    refresh_hw_device $hw_device
} else {
    puts "WARNING: LTX file not found: $ltx"
}

puts "Loaded bitstream $bit and probes from $ltx"
puts "Current HW device: $hw_device"

# Reset procedure, VIO name given as argument
proc reset_board {vio_name} {
    # Get current device
    set dev [lindex [get_hw_devices] 0]
    if {$dev eq ""} {
        puts "ERROR: no hw device found"
        return
    }

    # Get the VIO core
    set vio [get_hw_vios -of_objects $dev -filter {CELL_NAME=~"i_vio"}]
    if {$vio eq ""} {
        puts "ERROR: VIO core with CELL_NAME=~\"i_vio\" not found"
        return
    }

    # Probe
    set p [get_hw_probes $vio_name -of_objects $vio -quiet]
    if {$p eq ""} {
        puts "ERROR: probe $vio_name not found"
        return
    }

    # Assert
    set_property OUTPUT_VALUE 1 $p
    commit_hw_vio $vio
    after 500

    # Deassert
    set_property OUTPUT_VALUE 0 $p
    commit_hw_vio $vio

    puts "Board reset ($vio_name)"
}

# Alias
proc rst {} {
    global vio_default
    reset_board $vio_default
}

puts ""
puts "===================================="
puts "  Vivado Interactive HW Session"
puts "===================================="
puts ""
puts "Commands:"
puts "  reset_board <vio>   Reset board using specified VIO probe"
puts "  rst                 Reset board using default probe ($vio_default)"
puts "  q                   Exit session"
puts ""

# Should be launched with -mode tcl
