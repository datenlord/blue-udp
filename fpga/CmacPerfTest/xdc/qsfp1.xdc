# QSFP1
set_property PACKAGE_PIN D11 [get_ports {qsfp_ref_clk_p}]
set_property PACKAGE_PIN D10 [get_ports {qsfp_ref_clk_n}]

set_property PACKAGE_PIN E9 [get_ports {qsfp_txp_out[0]}]
set_property PACKAGE_PIN E8 [get_ports {qsfp_txn_out[0]}]
set_property PACKAGE_PIN D7 [get_ports {qsfp_txp_out[1]}]
set_property PACKAGE_PIN D6 [get_ports {qsfp_txn_out[1]}]
set_property PACKAGE_PIN C9 [get_ports {qsfp_txp_out[2]}]
set_property PACKAGE_PIN C8 [get_ports {qsfp_txn_out[2]}]
set_property PACKAGE_PIN A9 [get_ports {qsfp_txp_out[3]}]
set_property PACKAGE_PIN A8 [get_ports {qsfp_txn_out[3]}]

set_property PACKAGE_PIN E4 [get_ports {qsfp_rxp_in[0]}]
set_property PACKAGE_PIN E3 [get_ports {qsfp_rxn_in[0]}]
set_property PACKAGE_PIN D2 [get_ports {qsfp_rxp_in[1]}]
set_property PACKAGE_PIN D1 [get_ports {qsfp_rxn_in[1]}]
set_property PACKAGE_PIN C4 [get_ports {qsfp_rxp_in[2]}]
set_property PACKAGE_PIN C3 [get_ports {qsfp_rxn_in[2]}]
set_property PACKAGE_PIN A5 [get_ports {qsfp_rxp_in[3]}]
set_property PACKAGE_PIN A4 [get_ports {qsfp_rxn_in[3]}]

set_property PACKAGE_PIN BB9 [get_ports {qsfp_lpmode_out}]
set_property IOSTANDARD LVCMOS12 [get_ports qsfp_lpmode_out]

set_property PACKAGE_PIN BA7 [get_ports {qsfp_resetl_out}]
set_property IOSTANDARD LVCMOS12 [get_ports qsfp_resetl_out]
