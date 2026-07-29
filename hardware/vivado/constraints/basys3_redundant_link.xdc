## ============================================================================
## Basys3 Constraints - Dual-Channel Fault-Tolerant UART Link SoC
##
## Block Design Wrapper external ports:
##   rs422_rx_a_0
##   rs422_rx_b_0
##   rs422_tx_out_0
##   seg_0[6:0]
##   dp_0
##   an_0[3:0]
##
## sys_clock and reset are assigned by the Basys3 Board Interface in the
## Block Design and are intentionally not duplicated here.
## ============================================================================

## Pmod JA - UART / RS-422 transceiver logic-side signals
set_property -dict {PACKAGE_PIN J1 IOSTANDARD LVCMOS33} [get_ports rs422_rx_a_0]
set_property -dict {PACKAGE_PIN L2 IOSTANDARD LVCMOS33} [get_ports rs422_rx_b_0]
set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS33} [get_ports rs422_tx_out_0]

set_property PULLTYPE PULLUP [get_ports rs422_rx_a_0]
set_property PULLTYPE PULLUP [get_ports rs422_rx_b_0]
set_property DRIVE 8 [get_ports rs422_tx_out_0]
set_property SLEW SLOW [get_ports rs422_tx_out_0]

## Four-digit seven-segment display - active low
set_property -dict {PACKAGE_PIN W7 IOSTANDARD LVCMOS33} [get_ports {seg_0[0]}]
set_property -dict {PACKAGE_PIN W6 IOSTANDARD LVCMOS33} [get_ports {seg_0[1]}]
set_property -dict {PACKAGE_PIN U8 IOSTANDARD LVCMOS33} [get_ports {seg_0[2]}]
set_property -dict {PACKAGE_PIN V8 IOSTANDARD LVCMOS33} [get_ports {seg_0[3]}]
set_property -dict {PACKAGE_PIN U5 IOSTANDARD LVCMOS33} [get_ports {seg_0[4]}]
set_property -dict {PACKAGE_PIN V5 IOSTANDARD LVCMOS33} [get_ports {seg_0[5]}]
set_property -dict {PACKAGE_PIN U7 IOSTANDARD LVCMOS33} [get_ports {seg_0[6]}]
set_property -dict {PACKAGE_PIN V7 IOSTANDARD LVCMOS33} [get_ports dp_0]

set_property -dict {PACKAGE_PIN U2 IOSTANDARD LVCMOS33} [get_ports {an_0[0]}]
set_property -dict {PACKAGE_PIN U4 IOSTANDARD LVCMOS33} [get_ports {an_0[1]}]
set_property -dict {PACKAGE_PIN V4 IOSTANDARD LVCMOS33} [get_ports {an_0[2]}]
set_property -dict {PACKAGE_PIN W4 IOSTANDARD LVCMOS33} [get_ports {an_0[3]}]

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
