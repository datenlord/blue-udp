ROOT_DIR = $(abspath ..)
SCRIPTS_DIR = $(ROOT_DIR)/scripts
include $(SCRIPTS_DIR)/Makefile.base
LOCALSRCDIR = $(ROOT_DIR)/src:$(ROOT_DIR)/src/includes
LIBSRCDIR = $(ROOT_DIR)/lib/blue-crc/src:$(ROOT_DIR)/lib/blue-wrapper/src
CRC_TAB_SCRIPT = $(ROOT_DIR)/lib/blue-crc/scripts/gen_crc_tab.py

TARGET = XdmaUdpIpArpEthCmacRxTx
BSV_DIR = ./bsv
DUT_TOP ?= mk$(TARGET)
TB_FILE = $(BSV_DIR)/Test$(TARGET).bsv
TB_TOP = mkTest$(TARGET)


SUPPORT_RDMA ?= False
MACROFLAGS = -D IS_SUPPORT_RDMA=$(SUPPORT_RDMA)

# Pass arguments to vivado
export PART = xcvu13p-fhgb2104-2-i
export DIR_VLOG = ./verilog
export DIR_VLOG_GEN = ./generated/verilog
export DIR_XDC = ./xdc
export DIR_IP_TCL = ./tcl/ips
export DIR_IP_GEN = ./generated/ips
export DIR_OUTPUT = output
export GEN_IP_TCL = ./tcl/create_synth_ip.tcl

export SYNTH_ONLY = 0
export BUILD_TOP = XdmaUdpIpArpEthCmacRxTxWrapper
export SIM_TOP = TestUdpIpArpEthCmacRxTxWrapper
export TARGET_CLOCKS = clk_out1_clk_wiz_0
export MAX_NET_PATH_NUM = 1000

export PROJ_NAME = cmac_test
export CONFIG_FILE = ./verilog/sim_config.vh

ifeq ($(SUPPORT_RDMA), True)
export READ_MEM_FILE = 1
else
export READ_MEM_FILE = 0
endif

table:
ifeq ($(SUPPORT_RDMA), True)
	python3 $(CRC_TAB_SCRIPT) $(SCRIPTS_DIR)/crc_ieee_32_256.json $(BUILDDIR)
endif

verilog:
	mkdir -p $(BUILDDIR)
	bsc -elab $(VERILOGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(TRANSFLAGS) $(MACROFLAGS) -g $(DUT_TOP) $(BSV_DIR)/$(TARGET).bsv
	mkdir -p $(DIR_VLOG_GEN)
	bluetcl $(SCRIPTS_DIR)/listVlogFiles.tcl -bdir $(BUILDDIR) -vdir $(BUILDDIR) $(DUT_TOP) $(DUT_TOP) | grep -i '\.v' | xargs -I {} cp {} $(DIR_VLOG_GEN)

tb_verilog:
	mkdir -p $(BUILDDIR)
	mkdir -p $(DIR_VLOG_GEN)
	bsc -elab $(VERILOGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(TRANSFLAGS) $(MACROFLAGS) -g $(TB_TOP) $(TB_FILE)	
	bluetcl $(SCRIPTS_DIR)/listVlogFiles.tcl -bdir $(BUILDDIR) -vdir $(BUILDDIR) $(TB_TOP) $(TB_TOP) | grep -i '\.v' | xargs -I {} cp {} $(DIR_VLOG_GEN)

sim: table verilog tb_verilog
	vivado -mode batch -source ./tcl/vivado_sim.tcl 2>&1 | tee ./sim_run.log
#   rm -rf $(PROJ_NAME)

build: verilog
	vivado -mode batch -source ./tcl/vivado_build.tcl 2>&1 | tee ./build_run.log

clean:
	rm -rf $(BUILDDIR) $(DIR_VLOG_GEN) *.mem *.jou *.log $(PROJ_NAME) .Xil output


.PHONY: table verilog clean
.DEFAULT_GOAL := verilog
