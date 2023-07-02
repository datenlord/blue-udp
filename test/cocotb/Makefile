ROOT_DIR = $(abspath ../../)
SCRIPTS_DIR = $(ROOT_DIR)/scripts
include $(SCRIPTS_DIR)/Makefile.base
LOCALSRCDIR = $(ROOT_DIR)/src:$(ROOT_DIR)/src/includes
LIBSRCDIR = $(ROOT_DIR)/lib/blue-wrapper/src:$(ROOT_DIR)/lib/blue-crc/src

FILE ?= RdmaUdpIpEthTx.bsv
FILE_PATH = $(ROOT_DIR)/src
TOP ?= mkRawRdmaUdpIpEthTx
VLOGDIR = verilog
TARGET_FILE = $(VLOGDIR)/$(TOP).v

verilog:
	mkdir -p $(BUILDDIR)
	bsc -elab $(VERILOGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(TRANSFLAGS) -g $(TOP) $(FILE_PATH)/$(FILE)
	mkdir -p $(VLOGDIR)
	echo "" > $(TARGET_FILE)
	bluetcl $(SCRIPTS_DIR)/listVlogFiles.tcl -bdir $(BUILDDIR) -vdir $(BUILDDIR) $(TOP) $(TOP) | grep -i '\.v' | xargs -I {} cat {} >> $(TARGET_FILE)

clean:
	rm -rf $(BUILDDIR) __pycache__ .pytest_cache verilog


.PHONY: verilog clean
.DEFAULT_GOAL := verilog

