
# SLR Partition
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells {xdma_inst refclk_ibuf sys_reset_n_ibuf}]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells {perf_mon_inst perf_mon_ila_inst }]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells {clk_wiz_inst}]

set_property USER_SLR_ASSIGNMENT SLR2 [get_cells {udp_tx_axis_buf udp_cmac_inst2} ]

set_property USER_SLR_ASSIGNMENT SLR3 [get_cells {udp_cmac_inst1} ]
