
create_ip -name cmac_usplus -vendor xilinx.com -library ip -version 3.1 \
          -module_name cmac_usplus_0 -dir $dir_ip_gen -force

# User Parameters
set_property -dict [list \
  CONFIG.CMAC_CAUI4_MODE {1} \
  CONFIG.GT_DRP_CLk {250.00} \
  CONFIG.CMAC_CORE_SELECT {CMACE4_X0Y9} \
  CONFIG.GT_GROUP_SELECT {X1Y52~X1Y55} \
  CONFIG.INCLUDE_RS_FEC {1} \
  CONFIG.USER_INTERFACE {AXIS} \
] [get_ips cmac_usplus_0]