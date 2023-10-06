create_ip -name cmac_usplus -vendor xilinx.com -library ip -version 3.1 -module_name $cmac_module_name

set_property -dict [list \
  CONFIG.CMAC_CAUI4_MODE {1} \
  CONFIG.USER_INTERFACE {AXIS} \
] [get_ips $cmac_module_name]
