//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2024.2 (lin64) Build 5239630 Fri Nov 08 22:34:34 MST 2024
//Date        : Tue Jul 28 10:41:25 2026
//Host        : jbt9412-960QHA running 64-bit Ubuntu 26.04 LTS
//Command     : generate_target system_bd_wrapper.bd
//Design      : system_bd_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module system_bd_wrapper
   (an_0,
    dp_0,
    reset,
    rs422_rx_a_0,
    rs422_rx_b_0,
    rs422_tx_out_0,
    seg_0,
    sys_clock,
    usb_uart_rxd,
    usb_uart_txd);
  output [3:0]an_0;
  output dp_0;
  input reset;
  input rs422_rx_a_0;
  input rs422_rx_b_0;
  output rs422_tx_out_0;
  output [6:0]seg_0;
  input sys_clock;
  input usb_uart_rxd;
  output usb_uart_txd;

  wire [3:0]an_0;
  wire dp_0;
  wire reset;
  wire rs422_rx_a_0;
  wire rs422_rx_b_0;
  wire rs422_tx_out_0;
  wire [6:0]seg_0;
  wire sys_clock;
  wire usb_uart_rxd;
  wire usb_uart_txd;

  system_bd system_bd_i
       (.an_0(an_0),
        .dp_0(dp_0),
        .reset(reset),
        .rs422_rx_a_0(rs422_rx_a_0),
        .rs422_rx_b_0(rs422_rx_b_0),
        .rs422_tx_out_0(rs422_tx_out_0),
        .seg_0(seg_0),
        .sys_clock(sys_clock),
        .usb_uart_rxd(usb_uart_rxd),
        .usb_uart_txd(usb_uart_txd));
endmodule
