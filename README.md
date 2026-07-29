# Basys3 SoC Redundant UART / RS-422 Link

FPGA SoC project using a Basys3, MicroBlaze V, three custom FPGA IPs, and two STM32F411RE boards.
The STM32 Sender transmits the same ADC frame over independent A/B RS-422 channels. The FPGA
validates framing, length, CRC, sequence, payload, and channel health; applies failover/recovery and
fail-silent policy; forwards one selected frame; monitors the selected ADC value; and displays voltage
on the Basys3 FND. MicroBlaze V manages AXI configuration, interrupts, event logging, and terminal status.

## Repository structure

```text
hardware/
├─ ip/
│  ├─ redundant_link_core/
│  ├─ sensor_guard_ip/
│  └─ voltage_display_ip/
└─ vivado/

software/
├─ vitis/
└─ stm32/

docs/
```

## Key settings

- STM32 ↔ Basys3: 115200 8N1
- MicroBlaze V console: 9600 8N1
- Frame period: 100 ms
- Pair wait timeout: 10 ms
- Channel timeout: 300 ms
- Fail threshold: 3
- Recovery threshold: 5

## AXI address map

- Redundant Link Core: `0x00010000-0x00010FFF`
- Sensor Guard IP: `0x00020000-0x00020FFF`
- AXI UARTLite: `0x40600000`
- AXI INTC: `0x41200000`

## Final implementation evidence

Selected timing, DRC, route-status, bitstream, and ILA probe files are stored under
`hardware/vivado/results/`. Generated caches and transient build directories are not tracked.
