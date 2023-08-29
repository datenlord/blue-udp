ROOT_DIR = $(abspath ../../)
SCRIPTS_DIR = $(ROOT_DIR)/scripts
include $(SCRIPTS_DIR)/Makefile.base
LOCALSRCDIR = $(ROOT_DIR)/src:$(ROOT_DIR)/src/includes
LIB_CRC_DIR = $(ROOT_DIR)/lib/blue-crc/src
LIB_WRAPPER_DIR = $(ROOT_DIR)/lib/blue-wrapper/src
LIBSRCDIR = $(LIB_CRC_DIR):$(LIB_WRAPPER_DIR)
CRC_TAB_SCRIPT = $(ROOT_DIR)/lib/blue-crc/scripts/gen_crc_tab.py

TARGET = PfcUdpIpArpEthCmacRxTx
FILE_PATH = $(ROOT_DIR)/test/vivado
FILE_NAME ?= Test$(TARGET).bsv
TESTBENCH_TOP ?= mkTest$(TARGET)WithClkRst
DUT_TOP ?= mk$(TARGET)Inst
VLOGDIR = generated

export PROJ_NAME = cmac_test
export CONFIG_SRC = ./verilog/sim_config.vh
export SIM_SRC = ./verilog/Test$(TARGET)Wrapper.v


table:
	python3 $(CRC_TAB_SCRIPT) $(SCRIPTS_DIR)/crc_ieee_32_256.json ./

verilog:
	mkdir -p $(BUILDDIR)
	bsc -elab $(VERILOGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(TRANSFLAGS) -g $(TESTBENCH_TOP) $(FILE_PATH)/$(FILE_NAME)
	bsc -elab $(VERILOGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(TRANSFLAGS) -g $(DUT_TOP) $(FILE_PATH)/$(FILE_NAME)
	mkdir -p $(VLOGDIR)
	bluetcl $(SCRIPTS_DIR)/listVlogFiles.tcl -bdir $(BUILDDIR) -vdir $(BUILDDIR) $(TESTBENCH_TOP) $(TESTBENCH_TOP) | grep -i '\.v' | xargs -I {} cp {} $(VLOGDIR)
	bluetcl $(SCRIPTS_DIR)/listVlogFiles.tcl -bdir $(BUILDDIR) -vdir $(BUILDDIR) $(DUT_TOP) $(DUT_TOP) | grep -i '\.v' | xargs -I {} cp {} $(VLOGDIR)

sim: verilog
#	vivado -mode tcl
	vivado -mode batch -source vivado_sim.tcl 2>&1 | tee ./run.log
#rm -rf $(PROJ_NAME)

clean:
	rm -rf $(BUILDDIR) $(VLOGDIR) $(PROJ_NAME) *.mem .Xil *.jou *.log *.str


.PHONY: table verilog clean
.DEFAULT_GOAL := sim

