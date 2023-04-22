import netifaces


def get_default_gateway():
    return netifaces.gateways()['default'][netifaces.AF_INET][0]

def get_default_ifc_name():
    return netifaces.gateways()['default'][netifaces.AF_INET][1]

def get_default_ip_addr():
    ifc = get_default_ifc_name()
    return netifaces.ifaddresses(ifc)[netifaces.AF_INET][0]['addr']

def get_default_mac_addr():
    ifc = get_default_ifc_name()
    return netifaces.ifaddresses(ifc)[netifaces.AF_LINK][0]['addr']

def get_default_netmask():
    ifc = get_default_ifc_name()
    return netifaces.ifaddresses(ifc)[netifaces.AF_INET][0]['netmask']