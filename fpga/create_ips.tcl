create_ip -name cmac_usplus -vendor xilinx.com -library ip -version 3.1 -module_name $cmac_module_name

set_property -dict [list \
  CONFIG.CMAC_CAUI4_MODE {1} \
  CONFIG.USER_INTERFACE {AXIS} \
] [get_ips $cmac_module_name]

create_ip -name axis_data_fifo -vendor xilinx.com -library ip -version 2.0 -module_name axis_data_fifo_0
set_property -dict [list \
  CONFIG.FIFO_DEPTH {32} \
  CONFIG.HAS_TKEEP {1} \
  CONFIG.HAS_TLAST {1} \
  CONFIG.IS_ACLK_ASYNC {1} \
  CONFIG.SYNCHRONIZATION_STAGES {4} \
  CONFIG.TDATA_NUM_BYTES {64} \
  CONFIG.TUSER_WIDTH {1} \
] [get_ips axis_data_fifo_0]

