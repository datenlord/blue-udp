

create_ip -name ila -vendor xilinx.com -library ip -version 6.2 \
-module_name udp_perf_mon_ila -dir $dir_ip_gen -force

set_property -dict [list \
  CONFIG.C_NUM_OF_PROBES {16} \
  CONFIG.C_PROBE0_WIDTH {1} \
  CONFIG.C_PROBE1_WIDTH {1} \
  CONFIG.C_PROBE2_WIDTH {1} \
  CONFIG.C_PROBE3_WIDTH {1} \
  CONFIG.C_PROBE4_WIDTH {1} \
  CONFIG.C_PROBE5_WIDTH {32} \
  CONFIG.C_PROBE6_WIDTH {32} \
  CONFIG.C_PROBE7_WIDTH {32} \
  CONFIG.C_PROBE8_WIDTH {32} \
  CONFIG.C_PROBE9_WIDTH {32} \
  CONFIG.C_PROBE10_WIDTH {32} \
  CONFIG.C_PROBE11_WIDTH {32} \
  CONFIG.C_PROBE12_WIDTH {32} \
  CONFIG.C_PROBE13_WIDTH {32} \
  CONFIG.C_PROBE14_WIDTH {32} \
  CONFIG.C_PROBE15_WIDTH {32} \
] [get_ips udp_perf_mon_ila]
