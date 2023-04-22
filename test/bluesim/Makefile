include ../Makefile.base

TESTFILE ?= TestUdpArpEthRxTx.bsv
TOP ?= mkTestUdpArpEthRxTx

SIMEXE = $(BUILDDIR)/$(TOP).exe

compile:
	mkdir -p $(BUILDDIR)
#	bsc -elab -sim -verbose $(BLUESIMFLAGS) $(DEBUGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(SCHEDFLAGS) $(TRANSFLAGS) -g $(TOP) $(TESTFILE)
	bsc -elab -sim $(BLUESIMFLAGS) $(DEBUGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(SCHEDFLAGS) $(TRANSFLAGS) -g $(TOP) $(TESTFILE)
link: compile
	bsc -sim $(BLUESIMFLAGS) $(DIRFLAGS) $(RECOMPILEFLAGS) $(SCHEDFLAGS) $(TRANSFLAGS) -e $(TOP) -o $(SIMEXE)

simulate: link
	$(SIMEXE)

clean:
	rm -rf $(BUILDDIR)

.PHONY: compile link simulate clean
.DEFAULT_GOAL := simulate

