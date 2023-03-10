bscflags = -keep-fires -aggressive-conditions
srcdir = ../src
includedir = $(srcdir)/includes
buildDir = ../build

compile:
	mkdir -p $(buildDir)
	bsc -u -sim -simdir $(buildDir) -bdir $(buildDir) -info-dir $(buildDir) $(bscflags) -p +:$(srcdir):$(includedir) TestUdpTransmitter.bsv
	bsc -u -sim -simdir $(buildDir) -bdir $(buildDir) -info-dir $(buildDir) $(bscflags) -p +:$(srcdir):$(includedir) TestUdpReceiver.bsv
	bsc -u -sim -simdir $(buildDir) -bdir $(buildDir) -info-dir $(buildDir) $(bscflags) -p +:$(srcdir):$(includedir) TestUdpRxTx.bsv
	

udpTransmitter: compile
	bsc -sim -e mkTestUdpTransmitter -bdir $(buildDir) -info-dir $(buildDir) -simdir $(buildDir) -aggressive-conditions -keep-fires -o $(buildDir)/simUdpTransmitter
	$(buildDir)/simUdpTransmitter

udpRxTx: compile
	bsc -sim -e mkTestUdpRxTx -bdir $(buildDir) -info-dir $(buildDir) -simdir $(buildDir) -aggressive-conditions -keep-fires -o $(buildDir)/simUdpRxTx
	$(buildDir)/simUdpRxTx

clean:
	rm -rf $(buildDir)

.PHONY: clean compile
