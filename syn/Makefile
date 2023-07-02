ROOT_DIR = $(abspath ../)
SCRIPTS_DIR = $(ROOT_DIR)/scripts
include $(SCRIPTS_DIR)/Makefile.base
LOCALSRCDIR = $(ROOT_DIR)/src:$(ROOT_DIR)/src/includes
LIBSRCDIR = $(ROOT_DIR)/lib/blue-wrapper/src

PWD = $(shell pwd)
VLOGDIR = generated
OUTPUTDIR = output
ONLYSYNTH = 0
CLK = main_clock

TARGETFILE ?= $(ROOT_DIR)/src/UdpArpEthRxTx.bsv
TOPMODULE ?= mkRawUdpArpEthRxTx
export TOP = $(TOPMODULE)
export RTL = $(VLOGDIR)
export XDC = $(PWD)
export OUTPUT = $(OUTPUTDIR)
export SYNTHONLY = $(ONLYSYNTH)
export CLOCKS = $(CLK)

compile:
	mkdir -p $(BUILDDIR)
	bsc -elab -sim -verbose $(BLUESIMFLAGS) $(DEBUGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(SCHEDFLAGS) $(TRANSFLAGS) -g $(TOPMODULE) $(TARGETFILE)

verilog: compile
	mkdir -p $(VLOGDIR)
	bsc $(VERILOGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(TRANSFLAGS) -g $(TOPMODULE) $(TARGETFILE)
	bluetcl listVlogFiles.tcl -bdir $(BUILDDIR) -vdir $(BUILDDIR) $(TOPMODULE) $(TOPMODULE) | grep -i '\.v' | xargs -I {} cp {} $(VLOGDIR)

vivado: verilog
	vivado -mode batch -source non_project_build.tcl 2>&1 | tee ./run.log

clean:
	rm -rf $(BUILDDIR) $(VLOGDIR) $(OUTPUTDIR) .Xil *.jou *.log

.PHONY: compile verilog clean vivado
.DEFAULT_GOAL := vivado