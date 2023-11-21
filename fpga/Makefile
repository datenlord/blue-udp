ROOT_DIR = $(abspath ..)
SCRIPTS_DIR = $(ROOT_DIR)/scripts
include $(SCRIPTS_DIR)/Makefile.base
LOCALSRCDIR = $(ROOT_DIR)/src:$(ROOT_DIR)/src/includes
LIBSRCDIR = $(ROOT_DIR)/lib/blue-crc/src:$(ROOT_DIR)/lib/blue-wrapper/src
CRC_TAB_SCRIPT = $(ROOT_DIR)/lib/blue-crc/scripts/gen_crc_tab.py

TARGET = XdmaUdpIpArpEthCmacRxTx
BSV_DIR = ./bsv
GEN_VLOG_DIR = generated
DUT_TOP ?= mk$(TARGET)
TB_FILE = $(BSV_DIR)/Test$(TARGET).bsv
TB_TOP = mkTest$(TARGET)

CMAC_CTRL = RawXilinxCmacController
CMAC_CTRL_TOP = mkRawXilinxCmacController
CMAC_CTRL_FILE = $(ROOT_DIR)/src/XilinxCmacController.bsv

SUPPORT_RDMA ?= False
MACROFLAGS = -D IS_SUPPORT_RDMA=$(SUPPORT_RDMA)

# Pass parameters to vivado
export SIM_TOP = TestUdpIpArpEthCmacRxTxWrapper
export PROJ_NAME = cmac_test
export INCLUDE_DIR = $(ROOT_DIR)/test/vivado/verilog/includes
export CONFIG_FILE = $(INCLUDE_DIR)/sim_config.vh
export SRC_DIR = ./verilog/
export GEN_SRC_DIR = $(GEN_VLOG_DIR)
export IP_TCL = create_ips.tcl
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
	bsc -elab $(VERILOGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(TRANSFLAGS) $(MACROFLAGS) -g $(CMAC_CTRL_TOP) $(CMAC_CTRL_FILE)
	
	mkdir -p $(GEN_VLOG_DIR)
	bluetcl $(SCRIPTS_DIR)/listVlogFiles.tcl -bdir $(BUILDDIR) -vdir $(BUILDDIR) $(DUT_TOP) $(DUT_TOP) | grep -i '\.v' | xargs -I {} cp {} $(GEN_VLOG_DIR)
	bluetcl $(SCRIPTS_DIR)/listVlogFiles.tcl -bdir $(BUILDDIR) -vdir $(BUILDDIR) $(CMAC_CTRL_TOP) $(CMAC_CTRL_TOP) | grep -i '\.v' | xargs -I {} cp {} $(GEN_VLOG_DIR)

tb_verilog:
	mkdir -p $(BUILDDIR)
	mkdir -p $(GEN_VLOG_DIR)
	bsc -elab $(VERILOGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(TRANSFLAGS) $(MACROFLAGS) -g $(TB_TOP) $(TB_FILE)	
	bluetcl $(SCRIPTS_DIR)/listVlogFiles.tcl -bdir $(BUILDDIR) -vdir $(BUILDDIR) $(TB_TOP) $(TB_TOP) | grep -i '\.v' | xargs -I {} cp {} $(GEN_VLOG_DIR)


sim: #table verilog tb_verilog
	vivado -mode batch -source vivado_sim.tcl 2>&1 | tee ./run.log
#   rm -rf $(PROJ_NAME)

clean:
	rm -rf $(BUILDDIR) $(GEN_VLOG_DIR) *.mem *.jou *.log $(PROJ_NAME) .Xil


.PHONY: table verilog clean
.DEFAULT_GOAL := verilog

