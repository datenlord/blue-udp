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
CONTAINER_CLIENT_IP="10.1.1.48"
CONTAINER_SERVER_IP=(\
    "10.1.1.64" \
    "10.1.1.65" \
    "10.1.1.66" \
    "10.1.1.67" \
    "10.1.1.68" \
    "10.1.1.69" \
    "10.1.1.70" \
    "10.1.1.71" \
)

# generate json configuration file for python testbench
TEST_CONFIG_FILE=test_config.json
echo "{" > $TEST_CONFIG_FILE
echo -e "\"udp_port\": \"$PORT_NUM\"," >> $TEST_CONFIG_FILE
IP_ADDR_STR="\"${CONTAINER_SERVER_IP[0]}\""
for ((i=1; i<${#CONTAINER_SERVER_IP[@]}; i++))
do
IP_ADDR_STR="$IP_ADDR_STR, \"${CONTAINER_SERVER_IP[$i]}\""
done
echo -e "\"ip_addr\": [$IP_ADDR_STR]" >> $TEST_CONFIG_FILE
echo "}" >> $TEST_CONFIG_FILE

# Create Image
if [ $in_server == 1 ]; then
    docker build -f ./build_docker/Dockerfile -t $IMAGE_NAME ./build_docker
    NET_IFC=eth0
fi

# Create MacVLAN docker network
docker network create -d macvlan --subnet=$CONTAINER_NET --ip-range=$CONTAINER_NET -o macvlan_mode=bridge -o parent=$NET_IFC $DOCKER_NETWORK

# Create Client Container
docker kill `docker ps -a -q` || true # Clean all pending containers to release IP
for ((i=0; i<${#CONTAINER_SERVER_IP[@]}; i++))
do
    docker run --rm -d -v `pwd`:`pwd` -w `pwd` --net=mymacvlan --ip=${CONTAINER_SERVER_IP[$i]} --name "exch_server_${i}" $IMAGE_NAME python3 IpSocketLoopback.py $CONTAINER_CLIENT_IP $PORT_NUM
done


sleep 1 # Wait a while for server to ready
docker run --rm -v `pwd`:`pwd` -w `pwd` --net=mymacvlan --ip=$CONTAINER_CLIENT_IP --name exch_client $IMAGE_NAME python3 TestPfcUdpIpArpEthRxTx.py $TEST_CONFIG_FILE

# Clean containers and delete network
rm $TEST_CONFIG_FILE
docker kill `docker ps -a -q` || true
docker network rm $DOCKER_NETWORK