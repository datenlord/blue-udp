create_clock -period 2 -name main_clock [get_ports CLK]
# report_property [get_clocks CLK]; # Check clock properties e.g. jitter

# set_clock_groups -asynchronous \
#     -group [get_clocks -include_generated_clocks clk1] \
#     -group [get_clocks -include_generated_clocks clk2]

# set_clock_groups will override set_max_delay
# set_max_delay $DELAY -from [get_pins cell1/C] -to [get_pins cell2/D] -datapath_only