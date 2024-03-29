# QSFP1
set_property PACKAGE_PIN D11 [get_ports {qsfp1_ref_clk_p}]
set_property PACKAGE_PIN D10 [get_ports {qsfp1_ref_clk_n}]

set_property PACKAGE_PIN E9 [get_ports {qsfp1_txp_out[0]}]
set_property PACKAGE_PIN E8 [get_ports {qsfp1_txn_out[0]}]
set_property PACKAGE_PIN D7 [get_ports {qsfp1_txp_out[1]}]
set_property PACKAGE_PIN D6 [get_ports {qsfp1_txn_out[1]}]
set_property PACKAGE_PIN C9 [get_ports {qsfp1_txp_out[2]}]
set_property PACKAGE_PIN C8 [get_ports {qsfp1_txn_out[2]}]
set_property PACKAGE_PIN A9 [get_ports {qsfp1_txp_out[3]}]
set_property PACKAGE_PIN A8 [get_ports {qsfp1_txn_out[3]}]

set_property PACKAGE_PIN E4 [get_ports {qsfp1_rxp_in[0]}]
set_property PACKAGE_PIN E3 [get_ports {qsfp1_rxn_in[0]}]
set_property PACKAGE_PIN D2 [get_ports {qsfp1_rxp_in[1]}]
set_property PACKAGE_PIN D1 [get_ports {qsfp1_rxn_in[1]}]
set_property PACKAGE_PIN C4 [get_ports {qsfp1_rxp_in[2]}]
set_property PACKAGE_PIN C3 [get_ports {qsfp1_rxn_in[2]}]
set_property PACKAGE_PIN A5 [get_ports {qsfp1_rxp_in[3]}]
set_property PACKAGE_PIN A4 [get_ports {qsfp1_rxn_in[3]}]

set_property PACKAGE_PIN BC8     [get_ports {qsfp1_fault_in}]
set_property IOSTANDARD LVCMOS12 [get_ports {qsfp1_fault_in}]

set_property PACKAGE_PIN BB9     [get_ports {qsfp1_lpmode_out}]
set_property IOSTANDARD LVCMOS12 [get_ports {qsfp1_lpmode_out}]

set_property PACKAGE_PIN BA7     [get_ports {qsfp1_resetl_out}]
set_property IOSTANDARD LVCMOS12 [get_ports {qsfp1_resetl_out}]

set_property PACKAGE_PIN BE21    [get_ports {qsfp1_fault_indication}]
set_property IOSTANDARD LVCMOS12 [get_ports {qsfp1_fault_indication}]

set_property PACKAGE_PIN BF22    [get_ports {cmac1_rx_aligned_indication}]
set_property IOSTANDARD LVCMOS12 [get_ports {cmac1_rx_aligned_indication}]

# QSFP2
set_property PACKAGE_PIN Y11 [get_ports {qsfp2_ref_clk_p}]
set_property PACKAGE_PIN Y10 [get_ports {qsfp2_ref_clk_n}]

set_property PACKAGE_PIN AA9 [get_ports {qsfp2_txp_out[0]}]
set_property PACKAGE_PIN AA8 [get_ports {qsfp2_txn_out[0]}]
set_property PACKAGE_PIN Y7  [get_ports {qsfp2_txp_out[1]}]
set_property PACKAGE_PIN Y6  [get_ports {qsfp2_txn_out[1]}]
set_property PACKAGE_PIN W9  [get_ports {qsfp2_txp_out[2]}]
set_property PACKAGE_PIN W8  [get_ports {qsfp2_txn_out[2]}]
set_property PACKAGE_PIN V7  [get_ports {qsfp2_txp_out[3]}]
set_property PACKAGE_PIN V6  [get_ports {qsfp2_txn_out[3]}]

set_property PACKAGE_PIN AA4 [get_ports {qsfp2_rxp_in[0]}]
set_property PACKAGE_PIN AA3 [get_ports {qsfp2_rxn_in[0]}]
set_property PACKAGE_PIN Y2  [get_ports {qsfp2_rxp_in[1]}]
set_property PACKAGE_PIN Y1  [get_ports {qsfp2_rxn_in[1]}]
set_property PACKAGE_PIN W4  [get_ports {qsfp2_rxp_in[2]}]
set_property PACKAGE_PIN W3  [get_ports {qsfp2_rxn_in[2]}]
set_property PACKAGE_PIN V2  [get_ports {qsfp2_rxp_in[3]}]
set_property PACKAGE_PIN V1  [get_ports {qsfp2_rxn_in[3]}]

set_property PACKAGE_PIN BC11    [get_ports {qsfp2_fault_in}]
set_property IOSTANDARD LVCMOS12 [get_ports {qsfp2_fault_in}]

set_property PACKAGE_PIN BB7     [get_ports {qsfp2_lpmode_out}]
set_property IOSTANDARD LVCMOS12 [get_ports {qsfp2_lpmode_out}]

set_property PACKAGE_PIN BB10    [get_ports {qsfp2_resetl_out}]
set_property IOSTANDARD LVCMOS12 [get_ports {qsfp2_resetl_out}]

set_property PACKAGE_PIN BD21    [get_ports {qsfp2_fault_indication}]
set_property IOSTANDARD LVCMOS12 [get_ports {qsfp2_fault_indication}]

set_property PACKAGE_PIN BE22    [get_ports {cmac2_rx_aligned_indication}]
set_property IOSTANDARD LVCMOS12 [get_ports {cmac2_rx_aligned_indication}]
