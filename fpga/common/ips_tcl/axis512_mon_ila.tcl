
create_ip -name ila -vendor xilinx.com -library ip -version 6.2 \
-module_name axis512_mon_ila -dir $dir_ip_gen -force

set_property -dict [list \
  CONFIG.C_NUM_OF_PROBES {6} \
  CONFIG.C_PROBE0_WIDTH {1} \
  CONFIG.C_PROBE1_WIDTH {1} \
  CONFIG.C_PROBE2_WIDTH {1} \
  CONFIG.C_PROBE3_WIDTH {1} \
  CONFIG.C_PROBE4_WIDTH {64} \
  CONFIG.C_PROBE5_WIDTH {512} \
] [get_ips axis512_mon_ila]
