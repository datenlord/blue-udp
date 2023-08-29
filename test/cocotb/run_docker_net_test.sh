set -o errexit
set -o nounset
set -o xtrace

NET_IFC=wlp7s0
PORT_NUM=88
IMAGE_NAME=ethernet-test
DOCKER_NETWORK=mymacvlan
CONTAINER_NET="10.1.1.0/24"
CONTAINER_SERVER_IP="10.1.1.48"
CONTAINER_CLIENT_IP="10.1.1.64"

# Create Image
# docker build -f ./build_docker/Dockerfile -t $IMAGE_NAME ./build_docker

# Create MacVLAN docker network
docker network create -d macvlan --subnet=$CONTAINER_NET --ip-range=$CONTAINER_NET -o macvlan_mode=bridge -o parent=$NET_IFC $DOCKER_NETWORK

# Create Container
docker kill `docker ps -a -q` || true # Clean all pending containers to release IP
docker run --rm -d -v `pwd`:`pwd` -w `pwd` --net=mymacvlan --ip=$CONTAINER_SERVER_IP --name exch_server $IMAGE_NAME python3 UdpSocketLoopback.py $CONTAINER_SERVER_IP $PORT_NUM

sleep 1 # Wait a while for server to ready
docker run --rm -v `pwd`:`pwd` -w `pwd` --net=mymacvlan --ip=$CONTAINER_CLIENT_IP --name exch_client $IMAGE_NAME python3 TestUdpIpArpEthRxTx.py $CONTAINER_SERVER_IP $PORT_NUM

# Clean containers and delete network
docker kill `docker ps -a -q` || true
docker network rm $DOCKER_NETWORK