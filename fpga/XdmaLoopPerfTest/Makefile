ROOT_DIR = $(abspath ../../)
SCRIPTS_DIR = $(ROOT_DIR)/scripts
include $(SCRIPTS_DIR)/Makefile.base
LOCALSRCDIR = $(ROOT_DIR)/src:$(ROOT_DIR)/src/includes
LIBSRCDIR = $(ROOT_DIR)/lib/blue-wrapper/src:$(ROOT_DIR)/lib/blue-crc/src
BSV_DIR = ../common/bsv

# Pass arguments to vivado
export PART = xcvu13p-fhgb2104-2-i
export BUILD_TOP = XdmaLoopPerfTestWrapper

## Directories and Files
export DIR_VLOG = ./verilog
export DIR_VLOG_GEN = ./generated/verilog
export DIR_XDC = ./xdc
export DIR_IP_TCL = ./generated/ips_tcl
export DIR_IP_GEN = ./generated/ips
export DIR_OUTPUT = output
export DIR_MEM_CONFIG = ./generated/mem
export CONFIG_FILE = ./generated/impl_config.vh

## Flow Control
export SYNTH_ONLY = 0
export IS_WRITE_BITSTREAM = 1
export IS_WRITE_DEBUG_PROBES = 1

## Report Options
export TARGET_CLOCKS = xdma_axi_aclk
export MAX_NET_PATH_NUM = 1000

BSV_MODULES = XdmaPerfMonitor
IP = xdma_axil_desc xdma_perf_mon_ila axis512_mon_ila

verilog: $(BSV_MODULES)
$(BSV_MODULES):
	mkdir -p $(BUILDDIR)
	mkdir -p $(DIR_VLOG_GEN)
	bsc -elab $(VERILOGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(TRANSFLAGS) $(MACROFLAGS) -g mk$@ $(BSV_DIR)/$@.bsv
	bluetcl $(SCRIPTS_DIR)/listVlogFiles.tcl -bdir $(BUILDDIR) -vdir $(BUILDDIR) mk$@ mk$@ | grep -i '\.v' | xargs -I {} cp {} $(DIR_VLOG_GEN)

ip: $(IP)
$(IP):
	@mkdir -p $(DIR_IP_TCL)
	cp ../common/ips_tcl/$@.tcl $(DIR_IP_TCL)

config:
	@echo "// Implementation Configurations" > $(CONFIG_FILE)

build: verilog ip config
	vivado -mode batch -source ../common/tcl/non_proj_build.tcl 2>&1 | tee ./build_run.log

clean:
	rm -rf $(BUILDDIR) $(DIR_VLOG_GEN) $(CONFIG_FILE) $(DIR_IP_TCL) *.mem *.jou *.log .Xil output *.str *.txt

clean_ip:
	rm -rf $(DIR_IP_GEN)

clean_all: clean clean_ip
	rm -rf generated


.PHONY: verilog ip config build clean clean_ip clean_all
.DEFAULT_GOAL := verilog
