# QSFP2
set_property PACKAGE_PIN Y11 [get_ports {qsfp_ref_clk_p}]
set_property PACKAGE_PIN Y10 [get_ports {qsfp_ref_clk_n}]

set_property PACKAGE_PIN AA9 [get_ports {qsfp_txp_out[0]}]
set_property PACKAGE_PIN AA8 [get_ports {qsfp_txn_out[0]}]
set_property PACKAGE_PIN Y7 [get_ports {qsfp_txp_out[1]}]
set_property PACKAGE_PIN Y6 [get_ports {qsfp_txn_out[1]}]
set_property PACKAGE_PIN W9 [get_ports {qsfp_txp_out[2]}]
set_property PACKAGE_PIN W8 [get_ports {qsfp_txn_out[2]}]
set_property PACKAGE_PIN V7 [get_ports {qsfp_txp_out[3]}]
set_property PACKAGE_PIN V6 [get_ports {qsfp_txn_out[3]}]

set_property PACKAGE_PIN AA4 [get_ports {qsfp_rxp_in[0]}]
set_property PACKAGE_PIN AA3 [get_ports {qsfp_rxn_in[0]}]
set_property PACKAGE_PIN Y2 [get_ports {qsfp_rxp_in[1]}]
set_property PACKAGE_PIN Y1 [get_ports {qsfp_rxn_in[1]}]
set_property PACKAGE_PIN W4 [get_ports {qsfp_rxp_in[2]}]
set_property PACKAGE_PIN W3 [get_ports {qsfp_rxn_in[2]}]
set_property PACKAGE_PIN V2 [get_ports {qsfp_rxp_in[3]}]
set_property PACKAGE_PIN V1 [get_ports {qsfp_rxn_in[3]}]

set_property PACKAGE_PIN BC11    [get_ports {qsfp_fault_in}]
set_property IOSTANDARD LVCMOS12 [get_ports {qsfp_fault_in}]

set_property PACKAGE_PIN BB7     [get_ports {qsfp_lpmode_out}]
set_property IOSTANDARD LVCMOS12 [get_ports {qsfp_lpmode_out}]

set_property PACKAGE_PIN BB10    [get_ports {qsfp_resetl_out}]
set_property IOSTANDARD LVCMOS12 [get_ports {qsfp_resetl_out}]

set_property PACKAGE_PIN BD21    [get_ports {qsfp_fault_indication}]
set_property IOSTANDARD LVCMOS12 [get_ports {qsfp_fault_indication}]

set_property PACKAGE_PIN BE22    [get_ports {cmac_rx_aligned_indication}]
set_property IOSTANDARD LVCMOS12 [get_ports {cmac_rx_aligned_indication}]
