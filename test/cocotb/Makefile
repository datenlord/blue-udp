ROOT_DIR = $(abspath ../../)
SCRIPTS_DIR = $(ROOT_DIR)/scripts
include $(SCRIPTS_DIR)/Makefile.base
LOCALSRCDIR = $(ROOT_DIR)/src:$(ROOT_DIR)/src/includes
LIB_CRC_DIR = $(ROOT_DIR)/lib/blue-crc/src
LIB_WRAPPER_DIR = $(ROOT_DIR)/lib/blue-wrapper/src
LIBSRCDIR = $(LIB_CRC_DIR):$(LIB_WRAPPER_DIR)

TARGET = RdmaUdpArpEthRxTx
FILE_PATH = $(ROOT_DIR)/src
TEST_FILE = Test$(TARGET).py
DESIGN_FILE ?= $(TARGET).bsv
TOP ?= mkRaw$(TARGET)
VLOGDIR = verilog
VLOG_FILE = $(VLOGDIR)/$(TOP).v

table:
	python3 $(LIB_CRC_DIR)/gen_crc_tab.py 32 256

verilog:
	mkdir -p $(BUILDDIR)
	bsc -elab $(VERILOGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(TRANSFLAGS) -g $(TOP) $(FILE_PATH)/$(DESIGN_FILE)
	mkdir -p $(VLOGDIR)
	echo "" > $(VLOG_FILE)
	bluetcl $(SCRIPTS_DIR)/listVlogFiles.tcl -bdir $(BUILDDIR) -vdir $(BUILDDIR) $(TOP) $(TOP) | grep -i '\.v' | xargs -I {} cat {} >> $(VLOG_FILE)

cocotb: verilog table
	python3 $(TEST_FILE)

clean:
	rm -rf $(BUILDDIR) __pycache__ .pytest_cache verilog *.mem


.PHONY: table verilog cocotb clean
.DEFAULT_GOAL := verilog

