#!/bin/bash

set -o errexit
set -o nounset
set -o xtrace

in_server=0
while getopts 's' op; do
    if [ $op == 's' ]; then
        in_server=1
    fi
done

if [ $in_server == 1 ]; then
    BASH_PROFILE=$HOME/.bash_profile
    if [ -f "$BASH_PROFILE" ]; then
        source $BASH_PROFILE
    fi
fi

# Update submodules
git submodule update --init --recursive

# Check or format Code format
echo -e "\nStart check code format"
if [ $in_server == 1 ]; then
    black --check $(find ./ -name "*.py")
else
    black $(find ./ -name "*.py")
fi

ROOT_DIR=`pwd`
TEST_DIR=${ROOT_DIR}/test/
# Run Cocotb Testbench
cd ${TEST_DIR}/cocotb
# Run Tests with SUPPORT_RDMA=True
echo -e "\nStart testing UdpIpEthTx with SUPPORT_RDMA=True"
make cocotb TARGET=UdpIpEthTx SUPPORT_RDMA=True

echo -e "\nStart testing UdpIpEthRx with SUPPORT_RDMA=True"
make cocotb TARGET=UdpIpEthRx SUPPORT_RDMA=True

make clean

# Run Tests with SUPPORT_RDMA=False
echo -e "\nStart testing UdpIpEthTx with SUPPORT_RDMA=False"
make cocotb TARGET=UdpIpEthTx SUPPORT_RDMA=False

echo -e "\nStart testing UdpIpEthRx with SUPPORT_RDMA=False"
make cocotb TARGET=UdpIpEthRx SUPPORT_RDMA=False

make clean

# Run Bluesim Testbench
cd ${TEST_DIR}/bluesim
echo -e "\nStart testing UdpIpEthBypassRxTx with SUPPORT_RDMA=False"
make sim TARGET=UdpIpEthBypassRxTx SUPPORT_RDMA=False

make clean

echo -e "\nStart testing UdpIpEthBypassRxTx with SUPPORT_RDMA=True"
make sim TARGET=UdpIpEthBypassRxTx SUPPORT_RDMA=True



# Test UdpIpArpEthRxTx on virtual docker network

# echo -e "\nStart testing UdpIpArpEthRxTx on docker virtual network"

# make verilog TARGET=UdpIpArpEthRxTx SUPPORT_RDMA=False
# if [ $in_server == 1 ]; then
#     ./run_udp_docker_test.sh -s
# else
#     ./run_udp_docker_test.sh
# fi


