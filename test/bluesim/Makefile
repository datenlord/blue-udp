ROOT_DIR = $(abspath ../../)
SCRIPTS_DIR = $(ROOT_DIR)/scripts
include $(SCRIPTS_DIR)/Makefile.base
LOCALSRCDIR = $(ROOT_DIR)/src:$(ROOT_DIR)/src/includes
LIBSRCDIR = $(ROOT_DIR)/lib/blue-wrapper/src:$(ROOT_DIR)/lib/blue-crc/src
CRC_TAB_SCRIPT = $(ROOT_DIR)/lib/blue-crc/scripts/gen_crc_tab.py

TARGET ?= PriorityFlowControl
TESTFILE = Test$(TARGET).bsv
TOP = mkTest$(TARGET)
SUPPORT_RDMA ?= True

SIMEXE = $(BUILDDIR)/$(TOP).exe

MACROFLAGS = -D IS_SUPPORT_RDMA=$(SUPPORT_RDMA)

table:
ifeq ($(SUPPORT_RDMA), True)
	python3 $(CRC_TAB_SCRIPT) $(SCRIPTS_DIR)/crc_ieee_32_1024.json ./
endif

compile:
	mkdir -p $(BUILDDIR)
#	bsc -elab -sim -verbose $(BLUESIMFLAGS) $(DEBUGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(SCHEDFLAGS) $(TRANSFLAGS) -g $(TOP) $(TESTFILE)
	bsc -elab -sim $(BLUESIMFLAGS) $(DEBUGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(SCHEDFLAGS) $(TRANSFLAGS) $(MACROFLAGS) -g $(TOP) $(TESTFILE)
link: compile
	bsc -sim $(BLUESIMFLAGS) $(DIRFLAGS) $(RECOMPILEFLAGS) $(SCHEDFLAGS) $(TRANSFLAGS) -e $(TOP) -o $(SIMEXE)

sim: link table
	$(SIMEXE)

clean:
	rm -rf $(BUILDDIR) *.mem

.PHONY: compile link simulate clean
.DEFAULT_GOAL := sim

