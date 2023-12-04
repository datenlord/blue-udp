# 复位与时钟端口关联
#set_property LOC [get_package_pins -filter {PIN_FUNC =~ *_PERSTN0_65}] [get_ports pcie_rst_n]
#set_property LOC [get_package_pins -of_objects [get_bels [get_sites -filter {NAME =~ *COMMON*} -of_objects [get_iobanks -of_objects [get_sites GTYE4_CHANNEL_X1Y23]]]/REFCLK0P]] [get_ports pcie_clk_p]
#set_property LOC [get_package_pins -of_objects [get_bels [get_sites -filter {NAME =~ *COMMON*} -of_objects [get_iobanks -of_objects [get_sites GTYE4_CHANNEL_X1Y23]]]/REFCLK0N]] [get_ports pcie_clk_n]

# 比特流相关
#set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN div-1 [current_design]
#set_property BITSTREAM.CONFIG.BPI_SYNC_MODE Type1 [current_design]
#set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
#set_property BITSTREAM.CONFIG.UNUSEDPIN Pulldown [current_design]

# 全局电平标准
set_property PULLUP true [get_ports pcie_rst_n]
set_property CONFIG_MODE BPI16 [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property IOSTANDARD LVCMOS18 [get_ports pcie_rst_n]

# PCIe Clock
create_clock -name sys_clk -period 10 [get_ports pcie_clk_p]

# XDMA LED
set_property PACKAGE_PIN BA20 [get_ports {user_lnk_up}]
set_property IOSTANDARD LVCMOS18 [get_ports {user_lnk_up}]

# SLR Partition
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells {clk_wiz_inst xdma_inst refclk_ibuf sys_reset_n_ibuf}]
set_property USER_SLR_ASSIGNMENT SLR2 [get_cells {udp_cmac_inst2 xdma_tx_axis_buf} ]
set_property USER_SLR_ASSIGNMENT SLR3 [get_cells {udp_cmac_inst1 } ]

#set_property USER_SLR_ASSIGNMENT SLR2 [get_cells {udp_cmac_inst2 tx_axis_sync_fifo rx_axis_sync_fifo xdma_rx_axis_ila xdma_c2h_axis_ila xdma_h2c_axis_ila} ]
#set_property USER_SLR_ASSIGNMENT SLR3 [get_cells {udp_cmac_inst1 xdma_tx_axis_ila } ]
