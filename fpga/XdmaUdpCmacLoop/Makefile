ROOT_DIR = $(abspath ../../)
SCRIPTS_DIR = $(ROOT_DIR)/scripts
include $(SCRIPTS_DIR)/Makefile.base
LOCALSRCDIR = $(ROOT_DIR)/src:$(ROOT_DIR)/src/includes
LIBSRCDIR = $(ROOT_DIR)/lib/blue-wrapper/src:$(ROOT_DIR)/lib/blue-crc/src
CRC_TAB_SCRIPT = $(ROOT_DIR)/lib/blue-crc/scripts/gen_crc_tab.py
BSV_DIR = ../common/bsv

# Design Configurations
# ENABLE_CMAC_RSFEC: 0 - Disable, 1 - Enable
# ENABLE_ARP_PROCESS: 0 - Disable, 1 - Enable
# ENABLE_DEBUG_MODE: 0 - Disable, 1 - Enable
# SUPPORT_RDMA: False - Disable, True - Enable
ENABLE_CMAC_RSFEC = 1
ENABLE_ARP_PROCESS = 0
ENABLE_DEBUG_MODE = 1
SUPPORT_RDMA ?= False

MACROFLAGS = -D IS_SUPPORT_RDMA=$(SUPPORT_RDMA)

# Pass arguments to vivado
export PART = xcvu13p-fhgb2104-2-i
export BUILD_TOP = XdmaUdpCmacLoopWrapper

## Directories and Files
export DIR_VLOG = ./verilog
export DIR_VLOG_GEN = ./generated/verilog
export DIR_XDC = ./generated/xdc
export DIR_IP_TCL = ./generated/ips_tcl
export DIR_IP_GEN = ./gen_ips
export DIR_OUTPUT = output
export DIR_MEM_CONFIG = ./generated/mem
export SYNTH_IMPL_OPTS_FILE = ./tcl/synth_impl_opts.tcl 
export CONFIG_FILE = ./generated/design_config.vh

## Flow Control
export SYNTH_EN = 1
export PLACE_EN = 1
export ROUTE_EN = 1
export BITSTREAM_EN = 0
export DEBUG_PROBES_EN = 0

## Report Options
export TARGET_CLOCKS = xdma_axi_aclk
export MAX_NET_PATH_NUM = 1000

BSV_MODULES = CmacRecvMonitor CmacSendMonitor XdmaUdpIpArpEthCmacRxTx XdmaUdpIpEthCmacRxTx
IP = xdma clk_wiz cmac_mon_ila axis512_mon_ila
ifeq ($(ENABLE_CMAC_RSFEC), 1)
IP += cmac_rsfec_q2
else
IP += cmac_q2
endif
XDC = common pciex16 qsfp_loop


table:
ifeq ($(SUPPORT_RDMA), True)
	python3 $(CRC_TAB_SCRIPT) $(SCRIPTS_DIR)/crc_ieee_32_256.json $(DIR_MEM_CONFIG)
endif

verilog: $(BSV_MODULES)
	cp ../common/verilog/UdpCmacRxTxWrapper.v $(DIR_VLOG_GEN)
$(BSV_MODULES):
	mkdir -p $(BUILDDIR)
	mkdir -p $(DIR_VLOG_GEN)
	bsc -elab $(VERILOGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(TRANSFLAGS) $(MACROFLAGS) -g mk$@ $(BSV_DIR)/$@.bsv
	bluetcl $(SCRIPTS_DIR)/listVlogFiles.tcl -bdir $(BUILDDIR) -vdir $(BUILDDIR) mk$@ mk$@ | grep -i '\.v' | xargs -I {} cp {} $(DIR_VLOG_GEN)

ip: $(IP)
$(IP):
	@mkdir -p $(DIR_IP_TCL)
	cp ../common/ips_tcl/$@.tcl $(DIR_IP_TCL)

xdc: $(XDC)
	cp ./xdc/*.xdc $(DIR_XDC)
$(XDC):
	@mkdir -p $(DIR_XDC)
	cp ../common/xdc/$@.xdc $(DIR_XDC)

config:
	@echo "// Implementation Configurations" > $(CONFIG_FILE)
ifeq ($(ENABLE_CMAC_RSFEC), 1)
	@echo "\`define ENABLE_CMAC_RSFEC" >> $(CONFIG_FILE)
endif
ifeq ($(ENABLE_ARP_PROCESS), 1)
	@echo "\`define ENABLE_ARP_PROCESS" >> $(CONFIG_FILE)
endif
ifeq ($(ENABLE_DEBUG_MODE), 1)
	@echo "\`define ENABLE_DEBUG_MODE" >> $(CONFIG_FILE)
endif

build: table verilog ip xdc config
	vivado -mode batch -source ../common/tcl/non_proj_build.tcl 2>&1 | tee ./build_run.log

clean:
	rm -rf $(BUILDDIR) $(DIR_VLOG_GEN) $(DIR_IP_TCL) $(DIR_XDC) $(CONFIG_FILE) $(DIR_MEM_CONFIG) *.jou *.log .Xil output

clean_ip:
	rm -rf $(DIR_IP_GEN)

clean_all: clean clean_ip
	rm -rf generated

.PHONY: table verilog ip xdc config build clean clean_ip clean_all
.DEFAULT_GOAL := verilog
