import netifaces
from cocotbext.axi.stream import define_stream

IP_ADDR_BYTE_NUM = 4
MAC_ADDR_BYTE_NUM = 6
UDP_PORT_BYTE_NUM = 2

(
    UdpConfigBus,
    UdpConfigTransation,
    UdpConfigSource,
    UdpConfigSink,
    UdpConfigMonitor,
) = define_stream(
    "UdpConfig",
    signals=["valid", "ready", "mac_addr", "ip_addr", "net_mask", "gate_way"],
)

(
    UdpIpMetaDataBus,
    UdpIpMetaDataTransation,
    UdpIpMetaDataSource,
    UdpIpMetaDataSink,
    UdpIpMetaDataMonitor,
) = define_stream(
    "UdpIpMetaData",
    signals=[
        "valid",
        "ready",
        "ip_addr",
        "ip_dscp",
        "ip_ecn",
        "dst_port",
        "src_port",
        "data_len",
    ],
)

(
    MacMetaDataBus,
    MacMetaDataTransaction,
    MacMetaDataSource,
    MacMetaDataSink,
    MacMetaDataMonitor,
) = define_stream("MacMetaData", signals=["valid", "ready", "mac_addr", "eth_type"])


def is_udp_ip_meta_equal(
    dut: UdpIpMetaDataTransation, ref: UdpIpMetaDataTransation
) -> bool:
    is_equal = dut.ip_addr == ref.ip_addr
    is_equal = is_equal & (dut.ip_dscp == ref.ip_dscp)
    is_equal = is_equal & (dut.ip_ecn == ref.ip_ecn)
    is_equal = is_equal & (dut.dst_port == ref.dst_port)
    is_equal = is_equal & (dut.src_port == ref.src_port)
    is_equal = is_equal & (dut.data_len == ref.data_len)
    return is_equal


def is_mac_meta_equal(dut: MacMetaDataTransaction, ref: MacMetaDataTransaction) -> bool:
    is_equal = dut.mac_addr == ref.mac_addr
    is_equal = is_equal & (dut.eth_type == ref.eth_type)
    return is_equal


def get_default_gateway():
    return netifaces.gateways()["default"][netifaces.AF_INET][0]


def get_default_ifc_name():
    return netifaces.gateways()["default"][netifaces.AF_INET][1]


def get_default_ip_addr():
    ifc = get_default_ifc_name()
    return netifaces.ifaddresses(ifc)[netifaces.AF_INET][0]["addr"]


def get_default_mac_addr():
    ifc = get_default_ifc_name()
    return netifaces.ifaddresses(ifc)[netifaces.AF_LINK][0]["addr"]


def get_default_netmask():
    ifc = get_default_ifc_name()
    return netifaces.ifaddresses(ifc)[netifaces.AF_INET][0]["netmask"]
