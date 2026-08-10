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
## sys_clock와 reset은 Block Design의 Basys3 Board Interface에서
## 핀과 IOSTANDARD가 지정되므로 이 파일에서 중복 설정하지 않습니다.
##
## 주의:
##   rs422_rx_a_0과 rs422_rx_b_0은 RS-422 수신 트랜시버의
##   3.3 V 단일 종단 로직 출력입니다.
##
##   RS-422 차동 A/B 신호를 Basys3 Pmod 핀에 직접 연결하면 안 됩니다.
##
##   rs422_tx_out_0은 Basys3가 선택한 최종 프레임의
##   3.3 V UART 로직 출력입니다.
## ============================================================================


## ----------------------------------------------------------------------------
## Pmod JA - UART / RS-422 transceiver logic-side signals
##
## JA1 / J1 : Channel A receiver logic output -> Basys3
## JA2 / L2 : Channel B receiver logic output -> Basys3
## JA3 / J2 : Basys3 selected UART TX -> STM32 #2 PA10
## ----------------------------------------------------------------------------

set_property -dict {PACKAGE_PIN J1 IOSTANDARD LVCMOS33} \
    [get_ports rs422_rx_a_0]

set_property -dict {PACKAGE_PIN L2 IOSTANDARD LVCMOS33} \
    [get_ports rs422_rx_b_0]

set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS33} \
    [get_ports rs422_tx_out_0]


## UART RX idle 상태는 High입니다.
## 외부 수신 모듈이 분리되거나 전원이 꺼졌을 때 입력이 뜨는 것을 방지합니다.

set_property PULLTYPE PULLUP [get_ports rs422_rx_a_0]
set_property PULLTYPE PULLUP [get_ports rs422_rx_b_0]


## Basys3 최종 UART TX 출력 설정

set_property DRIVE 8 [get_ports rs422_tx_out_0]
set_property SLEW SLOW [get_ports rs422_tx_out_0]


## ----------------------------------------------------------------------------
## Four-Digit Seven-Segment Display - Active Low
##
## voltage_display_ip 출력:
##   seg[6:0] = {g, f, e, d, c, b, a}
##
## 따라서:
##   seg_0[0] -> Segment A
##   seg_0[1] -> Segment B
##   seg_0[2] -> Segment C
##   seg_0[3] -> Segment D
##   seg_0[4] -> Segment E
##   seg_0[5] -> Segment F
##   seg_0[6] -> Segment G
##
## FND 표시 범위:
##   0.000 V ~ 3.300 V
## ----------------------------------------------------------------------------

set_property -dict {PACKAGE_PIN W7 IOSTANDARD LVCMOS33} \
    [get_ports {seg_0[0]}]

set_property -dict {PACKAGE_PIN W6 IOSTANDARD LVCMOS33} \
    [get_ports {seg_0[1]}]

set_property -dict {PACKAGE_PIN U8 IOSTANDARD LVCMOS33} \
    [get_ports {seg_0[2]}]

set_property -dict {PACKAGE_PIN V8 IOSTANDARD LVCMOS33} \
    [get_ports {seg_0[3]}]

set_property -dict {PACKAGE_PIN U5 IOSTANDARD LVCMOS33} \
    [get_ports {seg_0[4]}]

set_property -dict {PACKAGE_PIN V5 IOSTANDARD LVCMOS33} \
    [get_ports {seg_0[5]}]

set_property -dict {PACKAGE_PIN U7 IOSTANDARD LVCMOS33} \
    [get_ports {seg_0[6]}]

set_property -dict {PACKAGE_PIN V7 IOSTANDARD LVCMOS33} \
    [get_ports dp_0]


## ----------------------------------------------------------------------------
## Seven-Segment Digit Enables - Active Low
##
## an_0[3] : 왼쪽 자리
## an_0[2] : 가운데 왼쪽 자리
## an_0[1] : 가운데 오른쪽 자리
## an_0[0] : 오른쪽 자리
## ----------------------------------------------------------------------------

set_property -dict {PACKAGE_PIN U2 IOSTANDARD LVCMOS33} \
    [get_ports {an_0[0]}]

set_property -dict {PACKAGE_PIN U4 IOSTANDARD LVCMOS33} \
    [get_ports {an_0[1]}]

set_property -dict {PACKAGE_PIN V4 IOSTANDARD LVCMOS33} \
    [get_ports {an_0[2]}]

set_property -dict {PACKAGE_PIN W4 IOSTANDARD LVCMOS33} \
    [get_ports {an_0[3]}]


## ----------------------------------------------------------------------------
## Basys3 Configuration Bank Voltage
## ----------------------------------------------------------------------------

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]