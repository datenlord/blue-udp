# XDMA IP

create_ip -name xdma -vendor xilinx.com -library ip -version 4.1 \
          -module_name xdma_0 -dir $dir_ip_gen -force
set_property -dict [list \
  CONFIG.mode_selection {Basic} \
  CONFIG.pf0_msi_enabled {false} \
  CONFIG.cfg_mgmt_if {false} \
  CONFIG.pl_link_cap_max_link_speed {8.0_GT/s} \
  CONFIG.pl_link_cap_max_link_width {X16} \
  CONFIG.xdma_axi_intf_mm {AXI_Stream} \
] [get_ips xdma_0]
