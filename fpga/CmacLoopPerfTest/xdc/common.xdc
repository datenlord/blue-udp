
# Reset and Clock Ports
#set_property LOC [get_package_pins -filter {PIN_FUNC =~ *_PERSTN0_65}] [get_ports pcie_rst_n]
#set_property LOC [get_package_pins -of_objects [get_bels [get_sites -filter {NAME =~ *COMMON*} -of_objects [get_iobanks -of_objects [get_sites GTYE4_CHANNEL_X1Y23]]]/REFCLK0P]] [get_ports pcie_clk_p]
#set_property LOC [get_package_pins -of_objects [get_bels [get_sites -filter {NAME =~ *COMMON*} -of_objects [get_iobanks -of_objects [get_sites GTYE4_CHANNEL_X1Y23]]]/REFCLK0N]] [get_ports pcie_clk_n]

# Bitstream Config
#set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN div-1 [current_design]
#set_property BITSTREAM.CONFIG.BPI_SYNC_MODE Type1 [current_design]
#set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
#set_property BITSTREAM.CONFIG.UNUSEDPIN Pulldown [current_design]

# Voltage Config
set_property CONFIG_MODE BPI16 [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]

# XDMA LED
set_property PACKAGE_PIN BA20 [get_ports {user_lnk_up}]
set_property IOSTANDARD LVCMOS12 [get_ports {user_lnk_up}]

