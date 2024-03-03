
# SLR Partition
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells {xdma_inst refclk_ibuf sys_reset_n_ibuf}]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells {perfMonInst udp_rx_axis_ila udp_tx_axis_ila perf_mon_ila_inst}]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells {clk_wiz_inst}]

set_property USER_SLR_ASSIGNMENT SLR2 [get_cells {udp_rx_axis_buf udp_tx_axis_buf} ]

set_property USER_SLR_ASSIGNMENT SLR3 [get_cells {cmac_wrapper_inst} ]