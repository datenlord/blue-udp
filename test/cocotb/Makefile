include ../Makefile.base

FILE ?= UdpEthRx.bsv
FILE_PATH = ../../src/
TOP ?= mkUdpEthRx
VLOGDIR = verilog
TARGET_FILE = $(VLOGDIR)/$(TOP).v

verilog:
	mkdir -p $(BUILDDIR)
	bsc -elab $(VERILOGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(TRANSFLAGS) -g $(TOP) $(FILE_PATH)/$(FILE)
	mkdir -p $(VLOGDIR)
	echo "" > $(TARGET_FILE)
	bluetcl listVlogFiles.tcl -bdir $(BUILDDIR) -vdir $(BUILDDIR) $(TOP) $(TOP) | grep -i '\.v' | xargs -I {} cat {} >> $(TARGET_FILE)

clean:
	rm -rf $(BUILDDIR)
	rm -rf __pycache__
	rm -rf .pytest_cache

.PHONY: verilog clean
.DEFAULT_GOAL := verilog

