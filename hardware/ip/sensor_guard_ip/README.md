# Sensor Guard IP

Monitors the selected 12-bit ADC value after the redundant-link decision path.
Implements low/high threshold, delta, stale-data, statistics, and AXI4-Lite register control.

- `rtl/`: core, AXI register block, and top module
- `sim/`: available source testbench and waveform configuration
- `constraints/`: IP-local constraints
- `package/`: Vivado IP packaging metadata
