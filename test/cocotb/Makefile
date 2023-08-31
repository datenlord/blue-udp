ROOT_DIR = $(abspath ../../)
SCRIPTS_DIR = $(ROOT_DIR)/scripts
include $(SCRIPTS_DIR)/Makefile.base
LOCALSRCDIR = $(ROOT_DIR)/src:$(ROOT_DIR)/src/includes
LIB_CRC_DIR = $(ROOT_DIR)/lib/blue-crc/src
LIB_WRAPPER_DIR = $(ROOT_DIR)/lib/blue-wrapper/src
LIBSRCDIR = $(LIB_CRC_DIR):$(LIB_WRAPPER_DIR)
CRC_TAB_SCRIPT = $(ROOT_DIR)/lib/blue-crc/scripts/gen_crc_tab.py

TARGET = UdpIpEthTx
FILE_PATH = $(ROOT_DIR)/src
TEST_FILE = Test$(TARGET).py
DESIGN_FILE ?= $(TARGET).bsv
TOP ?= mkRaw$(TARGET)
VLOGDIR = verilog
VLOG_FILE = $(VLOGDIR)/$(TOP).v
SUPPORT_RDMA ?= False

MACROFLAGS = -D IS_SUPPORT_RDMA=$(SUPPORT_RDMA)

# docker virtual network configuration
IP_ADDR ?=
UDP_PORT ?=

table:
ifeq ($(SUPPORT_RDMA), True)
	python3 $(CRC_TAB_SCRIPT) $(SCRIPTS_DIR)/crc_ieee_32_256.json $(BUILDDIR)
endif

verilog:
	mkdir -p $(BUILDDIR)
	bsc -elab $(VERILOGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(TRANSFLAGS) $(MACROFLAGS) -g $(TOP) $(FILE_PATH)/$(DESIGN_FILE)
	mkdir -p $(VLOGDIR)
	echo "" > $(VLOG_FILE)
	bluetcl $(SCRIPTS_DIR)/listVlogFiles.tcl -bdir $(BUILDDIR) -vdir $(BUILDDIR) $(TOP) $(TOP) | grep -i '\.v' | xargs -I {} cat {} >> $(VLOG_FILE)

cocotb: verilog table
ifeq ($(TARGET), UdpIpArpEthRxTx)
	echo "Run run_docker_net_test.sh to test UdpIpArpEthRxTx"
else
	python3 $(TEST_FILE) $(SUPPORT_RDMA)
endif

clean:
	rm -rf $(BUILDDIR) __pycache__ .pytest_cache verilog *.mem


.PHONY: table verilog cocotb clean
.DEFAULT_GOAL := verilog

