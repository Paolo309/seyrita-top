# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Nicole Narr <narrn@student.ethz.ch>
# Christopher Reinwardt <creinwar@student.ethz.ch>
# Cyril Koenig <cykoenig@iis.ee.ethz.ch>
# Paul Scheffler <paulsc@iis.ee.ethz.ch>
# Yvan Tortorella <yvan.tortorella@gmail.com>
# Mojtaba Rostami <m.rostami1989@gmail.com>
# Paolo Galfano <paologalfano99@gmail.com>

VIVADO ?= vitis-2022.1 vivado

CHIM_XILINX_DIR := $(CHIM_ROOT)/target/xilinx

CHIM_BENDER_RTL_FLAGS := $(COMMON_TARGS)

# Required to split stems
.SECONDEXPANSION:

###############
# Generate HW #
###############

# FPGA-level configuration registers
# $(CHS_XILINX_DIR)/src/regs/chs_xilinx_reg_pkg.sv $(CHS_XILINX_DIR)/src/regs/chs_xilinx_reg_top.sv: $(CHS_XILINX_DIR)/src/regs/chs_xilinx_regs.hjson
# 	$(REGTOOL) -r $< --outdir $(dir $@)

CHIM_XILINX_HW := 

##############
# Xilinx IPs #
##############

.PRECIOUS: $(CHIM_XILINX_DIR)/build/%/ $(CHIM_XILINX_DIR)/build/%/out.xci

$(CHIM_XILINX_DIR)/build/%/:
	mkdir -p $@

# We split the stem into a board and an IP and resolve dependencies accordingly
$(CHIM_XILINX_DIR)/build/%/out.xci: \
		$(CHIM_XILINX_DIR)/scripts/impl_ip.tcl \
		$$(wildcard $(CHIM_XILINX_DIR)/src/ips/$$*.prj) \
		| $(CHIM_XILINX_DIR)/build/%/
	@rm -f $(CHIM_XILINX_DIR)/build/$(*)*.log $(CHIM_XILINX_DIR)/build/$(*)*.jou
	cd $| && $(VIVADO) -mode batch -log ../$*.log -jou ../$*.jou -source $< -tclargs $(subst ., ,$*)

##############
# Bitstreams #
##############

CHIM_XILINX_BOARDS := vcu118 vcu128

CHIM_XILINX_IPS_vcu118 := clkwiz vio
CHIM_XILINX_IPS_vcu128 := clkwiz vio

$(CHIM_XILINX_DIR)/scripts/add_sources.%.tcl: $(CHIM_ROOT)/Bender.yml $(CHIM_XILINX_HW)
	$(BENDER) script vivado -t fpga -t $* $(CHIM_BENDER_RTL_FLAGS) > $@

define chim_xilinx_bit_rule
$$(CHIM_XILINX_DIR)/out/%.$(1).bit: \
		$$(CHIM_XILINX_DIR)/scripts/impl_sys.tcl \
		$(CHIM_XILINX_DIR)/scripts/add_sources.$(1).tcl \
		$$(CHIM_XILINX_IPS_$(1):%=$(CHIM_XILINX_DIR)/build/$(1).%/out.xci) \
		| $$(CHIM_XILINX_DIR)/build/$(1).%/
	@rm -f $$(CHIM_XILINX_DIR)/build/$$*.$(1)*.log $$(CHIM_XILINX_DIR)/build/$$*.$(1)*.jou
	cd $$| && $$(VIVADO) -mode batch -log ../$$*.$(1).log -jou ../$$*.$(1).jou -source $$< \
		-tclargs $(1) $$* $$(CHIM_XILINX_IPS_$(1):%=$$(CHIM_XILINX_DIR)/build/$(1).%/out.xci)

CHIM_PHONY += chim-xilinx-$(1)
chim-xilinx-$(1): $$(CHIM_XILINX_DIR)/out/chimera.$(1).bit
endef

$(foreach board,$(CHIM_XILINX_BOARDS),$(eval $(call chim_xilinx_bit_rule,$(board))))

# Builds bitstreams for all available boards
CHIM_XILINX_ALL = $(foreach board,$(CHIM_XILINX_BOARDS),$$(CHIM_XILINX_DIR)/out/chimera.$(board).bit)

#############
# Utilities #
#############

# Parameters for HW server (defaults are for a unique board @ localhost).
# `CHS_XILINX_HWS_PATH_$(board)` overrides the device path for each board (default *).
CHIM_XILINX_HWS_URL ?= boardberg.ee.ethz.ch:12846

# We build the dependency file $(2) only if it does not exist; it must not be up to date.
# We add PHONYs for each board as despite the implicit rule, these should be explicit.
define chim_xilinx_util_rule
CHIM_PHONY += $(foreach board,$(CHIM_XILINX_BOARDS),chim-xilinx-$(1)-$(board))
$(foreach board,$(CHIM_XILINX_BOARDS),chim-xilinx-$(1)-$(board)): chim-xilinx-$(1)-%: \
		$$(CHIM_XILINX_DIR)/scripts/util/$(1).tcl | $$(CHIM_XILINX_DIR)/build/%.$(1)/
	[ -e $(subst %,$$*,$(2)) ] || $$(MAKE) $(subst %,$$*,$(2))
	@rm -f $$(CHIM_XILINX_DIR)/build/$$(*)*.$(1).log $$(CHIM_XILINX_DIR)/build/$$(*)*.$(1).jou
	cd $$| && $$(VIVADO) $(if $(3), -mode $(3) -notrace, -mode batch) -log ../$$(*).$(1).log -jou ../$$(*).$(1).jou -source $$< \
		-tclargs $$(CHIM_XILINX_HWS_URL) $$(or $$(CHIM_XILINX_HWS_PATH_$$*),{*}) $$* $(subst %,$$*,$(2)) 0
endef

# Program bitstream onto board
$(eval $(call chim_xilinx_util_rule,program,$(CHIM_XILINX_DIR)/out/chimera.%.bit))

# # Flash onboard memory with the file `CHS_XILINX_FLASH_IMG` (only selected boards).
# # `%` is substituted with the board name. The default is the Linux disk image for that board.
# CHS_XILINX_FLASH_IMG ?= $(CHS_SW_DIR)/boot/linux.%.gpt.bin
# $(eval $(call chs_xilinx_util_rule,flash,$(CHS_XILINX_FLASH_IMG)))

# Connect to the already programmed board
$(eval $(call chim_xilinx_util_rule,connect,$(CHIM_XILINX_DIR)/out/chimera.%.bit,tcl))

# Reset the board (must be already programmed)
$(eval $(call chim_xilinx_util_rule,reset,$(CHIM_XILINX_DIR)/out/chimera.%.bit))

xilinx-clean-out:
	rm -rf $(CHIM_XILINX_DIR)/out/
