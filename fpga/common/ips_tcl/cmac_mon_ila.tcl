
create_ip -name ila -vendor xilinx.com -library ip -version 6.2 \
-module_name cmac_mon_ila -dir $dir_ip_gen -force

set_property -dict [list \
  CONFIG.C_NUM_OF_PROBES {7} \
  CONFIG.C_PROBE0_WIDTH {1} \
  CONFIG.C_PROBE1_WIDTH {4} \
  CONFIG.C_PROBE2_WIDTH {32} \
  CONFIG.C_PROBE3_WIDTH {32} \
  CONFIG.C_PROBE4_WIDTH {32} \
  CONFIG.C_PROBE5_WIDTH {32} \
  CONFIG.C_PROBE6_WIDTH {32} \
] [get_ips cmac_mon_ila]
