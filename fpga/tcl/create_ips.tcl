# XDMA IP
create_ip -name xdma -vendor xilinx.com -library ip -version 4.1 -module_name xdma_0
set_property -dict [list \
  CONFIG.mode_selection {Basic} \
  CONFIG.pf0_msi_enabled {false} \
  CONFIG.cfg_mgmt_if {false} \
  CONFIG.pl_link_cap_max_link_speed {8.0_GT/s} \
  CONFIG.pl_link_cap_max_link_width {X16} \
  CONFIG.xdma_axi_intf_mm {AXI_Stream} \
] [get_ips xdma_0]

# Clock Wizard IP
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_wiz_0
# User Parameters
set_property -dict [list \
  CONFIG.CLKIN1_JITTER_PS {40.0} \
  CONFIG.CLKOUT1_JITTER {78.198} \
  CONFIG.CLKOUT1_PHASE_ERROR {85.928} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {500.000} \
  CONFIG.CLKOUT2_JITTER {107.111} \
  CONFIG.CLKOUT2_PHASE_ERROR {85.928} \
  CONFIG.CLKOUT2_USED {true} \
  CONFIG.MMCM_CLKFBOUT_MULT_F {4.000} \
  CONFIG.MMCM_CLKIN1_PERIOD {4.000} \
  CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {2.000} \
  CONFIG.MMCM_CLKOUT1_DIVIDE {10} \
  CONFIG.MMCM_DIVCLK_DIVIDE {1} \
  CONFIG.NUM_OUT_CLKS {2} \
  CONFIG.PRIM_IN_FREQ {250.000} \
  CONFIG.RESET_PORT {resetn} \
  CONFIG.RESET_TYPE {ACTIVE_LOW} \
] [get_ips clk_wiz_0]

# 100G CMAC IP
create_ip -name cmac_usplus -vendor xilinx.com -library ip -version 3.1 -module_name cmac_usplus_0
set_property -dict [list \
  CONFIG.CMAC_CAUI4_MODE {1} \
  CONFIG.USER_INTERFACE {AXIS} \
] [get_ips cmac_usplus_0]
