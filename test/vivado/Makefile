ROOT_DIR = $(abspath ../../)
SCRIPTS_DIR = $(ROOT_DIR)/scripts
include $(SCRIPTS_DIR)/Makefile.base
LOCALSRCDIR = $(ROOT_DIR)/src:$(ROOT_DIR)/src/includes
LIB_CRC_DIR = $(ROOT_DIR)/lib/blue-crc/src
LIB_WRAPPER_DIR = $(ROOT_DIR)/lib/blue-wrapper/src
LIBSRCDIR = $(LIB_CRC_DIR):$(LIB_WRAPPER_DIR)
CRC_TAB_SCRIPT = $(ROOT_DIR)/lib/blue-crc/scripts/gen_crc_tab.py

TARGET = UdpIpArpEthCmacRxTx
DUT_FILE = $(ROOT_DIR)/src/$(TARGET).bsv
DUT_TOP ?= mkRaw$(TARGET)
TB_FILE ?= ./bsv/Test$(TARGET).bsv
TB_TOP ?= mkTest$(TARGET)
VLOGDIR = generated
SUPPORT_RDMA ?= False

MACROFLAGS = -D IS_SUPPORT_RDMA=$(SUPPORT_RDMA)

# Pass parameters to vivado
export PROJ_NAME = cmac_test
export INCLUDE_DIR = ./verilog/includes
export CONFIG_FILE = $(INCLUDE_DIR)/sim_config.vh
export SRC_DIR = ./verilog/$(TARGET)
export GEN_SRC_DIR = $(VLOGDIR)
export IP_TCL = ./tcl/create_ips.tcl
ifeq ($(SUPPORT_RDMA), True)
export READ_MEM_FILE = 1
else
export READ_MEM_FILE = 0
endif

table:
ifeq ($(SUPPORT_RDMA), True)
	python3 $(CRC_TAB_SCRIPT) $(SCRIPTS_DIR)/crc_ieee_32_256.json $(GEN_SRC_DIR)
endif

verilog:
	mkdir -p $(BUILDDIR)
	bsc -elab $(VERILOGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(TRANSFLAGS) $(MACROFLAGS) -g $(DUT_TOP) $(DUT_FILE)	
	
	mkdir -p $(VLOGDIR)
	bluetcl $(SCRIPTS_DIR)/listVlogFiles.tcl -bdir $(BUILDDIR) -vdir $(BUILDDIR) $(DUT_TOP) $(DUT_TOP) | grep -i '\.v' | xargs -I {} cp {} $(VLOGDIR)

tb_verilog:
	mkdir -p $(BUILDDIR)
	bsc -elab $(VERILOGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(TRANSFLAGS) $(MACROFLAGS) -g $(TB_TOP) $(TB_FILE)
	mkdir -p $(VLOGDIR)
	bluetcl $(SCRIPTS_DIR)/listVlogFiles.tcl -bdir $(BUILDDIR) -vdir $(BUILDDIR) $(TB_TOP) $(TB_TOP) | grep -i '\.v' | xargs -I {} cp {} $(VLOGDIR)

sim: verilog table tb_verilog
#	vivado -mode tcl
	vivado -mode batch -source ./tcl/vivado_sim.tcl 2>&1 | tee ./run.log
	rm -rf $(PROJ_NAME)

clean:
	rm -rf $(BUILDDIR) $(VLOGDIR) $(PROJ_NAME) *.mem .Xil *.jou *.log *.str


.PHONY: table verilog clean
.DEFAULT_GOAL := sim

