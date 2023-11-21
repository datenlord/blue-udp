set -o errexit
set -o nounset
set -o xtrace

in_server=0
while getopts 's' option; do
    if [ $option == 's' ]; then
        in_server=1
    fi
done

NET_IFC=enp0s31f6
PORT_NUM=88
IMAGE_NAME=ethernet-test
DOCKER_NETWORK=mymacvlan
CONTAINER_NET="10.1.1.0/24"
CONTAINER_SERVER_IP="10.1.1.48"
CONTAINER_CLIENT_IP="10.1.1.64"

# generate json configuration file for python testbench
TEST_CONFIG_FILE=test_config.json
echo "{" > $TEST_CONFIG_FILE
echo -e "\"udp_port\": \"$PORT_NUM\"," >> $TEST_CONFIG_FILE
echo -e "\"ip_addr\": \"$CONTAINER_SERVER_IP\"" >> $TEST_CONFIG_FILE
echo "}" >> $TEST_CONFIG_FILE

# Create Image
if [ $in_server == 1 ]; then
    docker build -f ./build_docker/Dockerfile -t $IMAGE_NAME ./build_docker
    NET_IFC=eth0
fi

# Create MacVLAN docker network
docker network create -d macvlan --subnet=$CONTAINER_NET --ip-range=$CONTAINER_NET -o macvlan_mode=bridge -o parent=$NET_IFC $DOCKER_NETWORK

# Create Container
#docker kill `docker ps -a -q` || true # Clean all pending containers to release IP
docker run --rm -d -v `pwd`:`pwd` -w `pwd` --net=mymacvlan --ip=$CONTAINER_SERVER_IP --name exch_server $IMAGE_NAME python3 UdpSocketLoopback.py $CONTAINER_SERVER_IP $PORT_NUM

sleep 1 # Wait a while for server to ready
docker run --rm -v `pwd`:`pwd` -w `pwd` --net=mymacvlan --ip=$CONTAINER_CLIENT_IP --name exch_client $IMAGE_NAME python3 TestUdpIpArpEthRxTx.py $TEST_CONFIG_FILE
#make TARGET=UdpIpArpEthRxTx IP_ADDR=$CONTAINER_SERVER_IP UDP_PORT=$PORT_NUM

# Clean containers and delete network
#docker kill `docker ps -a -q` || true
docker network rm $DOCKER_NETWORK
rm $TEST_CONFIG_FILE