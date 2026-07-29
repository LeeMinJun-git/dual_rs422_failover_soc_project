# Basys3 SoC Redundant UART Link

Basys3, MicroBlaze V, three custom FPGA IPs, and two STM32F411RE boards are used to implement a fault-tolerant dual-channel UART/RS-422 communication system.

## Repository structure

```text
hardware/
├─ ip/
│  ├─ redundant_link_core/
│  ├─ sensor_guard_ip/
│  └─ voltage_display_ip/
└─ vivado/
   ├─ BLOCK_DESIGN.md
   ├─ constraints/
   └─ wrapper/

software/
├─ vitis/
└─ stm32/

docs/
└─ README.md
```

## Final system

The STM32 Sender transmits the same ADC frame through channels A and B. The Basys3 validates frame structure, CRC, sequence, and channel health, applies failover/recovery policy, forwards the selected frame to the STM32 Receiver, monitors the selected ADC value, and displays voltage on the FND. MicroBlaze V manages AXI configuration, interrupts, event logging, and terminal status.

## Key settings

- STM32 ↔ Basys3: `115200 8N1`
- MicroBlaze V console: `9600 8N1`
- Frame period: `100 ms`
- Pair wait timeout: `10 ms`
- Channel timeout: `300 ms`
- Fail threshold: `3`
- Recovery threshold: `5`

## AXI address map

- Redundant Link Core: `0x00010000-0x00010FFF`
- Sensor Guard IP: `0x00020000-0x00020FFF`
- AXI UARTLite: `0x40600000`
- AXI INTC: `0x41200000`

## Final implementation result

- Vivado 2024.2 implementation completed with 0 failed routes.
- Setup: WNS `+0.137 ns`, TNS `0`.
- Hold: WHS `+0.007 ns`, THS `0`.
- Bitstream/XSA generation and MicroBlaze V hardware execution completed.
- The uploaded source snapshots were used for the final hardware demonstration.
