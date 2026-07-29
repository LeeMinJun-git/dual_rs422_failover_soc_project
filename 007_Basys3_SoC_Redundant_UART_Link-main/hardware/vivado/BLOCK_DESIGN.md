# Final Vivado Block Design

The final demonstration was implemented with Vivado 2024.2 for the Basys3 `xc7a35tcpg236-1` device.

## Processing and AXI infrastructure

- MicroBlaze V (`microblaze_riscv`)
- 64 KiB local BRAM through ILMB/DLMB controllers
- Clocking Wizard, 100 MHz
- Processor System Reset
- AXI SmartConnect
- AXI UARTLite, `0x40600000`, console at 9600 8N1
- AXI Interrupt Controller, `0x41200000`
- System ILA on the Redundant Link AXI interface

## Custom IP instances

- `redundant_link_core_0`, AXI4-Lite `0x00010000-0x00010FFF`
- `sensor_guard_ip_0`, AXI4-Lite `0x00020000-0x00020FFF`
- `voltage_display_ip_0`, no AXI slave interface

## Data-path connections

```text
rs422_rx_a_0 ─┐
               ├─> redundant_link_core_0 ──> rs422_tx_out_0
rs422_rx_b_0 ─┘              │
                              ├─ selected_adc_raw ──> sensor_guard_ip_0.adc_raw
                              └─ selected_adc_valid -> sensor_guard_ip_0.adc_valid

sensor_guard_ip_0.current_adc   ──> voltage_display_ip_0.current_adc
sensor_guard_ip_0.display_valid ──> voltage_display_ip_0.display_valid
voltage_display_ip_0 ──> an_0[3:0], seg_0[6:0], dp_0
```

## Clock, reset, and interrupt

- All three custom IPs use the 100 MHz Clocking Wizard output.
- Custom IP active-high resets use `rst_clk_wiz_1_100M/peripheral_reset`.
- AXI peripherals use `peripheral_aresetn` as appropriate.
- `redundant_link_core_0/irq` connects to AXI INTC input 0.
- The internal `create_clock` constraint in Sensor Guard IP was removed/commented so the top-level Clocking Wizard constraint is the single clock definition.

## Final implementation result

- Failed routes: 0
- Setup WNS: `+0.137 ns`
- Setup TNS: `0`
- Hold WHS: `+0.007 ns`
- Hold THS: `0`
- Bitstream and hardware XSA generated successfully
