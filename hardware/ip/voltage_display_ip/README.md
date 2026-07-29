# Voltage Display IP

Converts the validated ADC sample to a voltage representation and drives the Basys3
four-digit seven-segment display.

- `rtl/`: conversion, BCD, scan, and top-level RTL
- `sim/`: self-checking testbench
- `scripts/`, `constraints/`: packaging and OOC verification support
- `reports/`, `docs/`: final delivery evidence
- `package/`: Vivado IP packaging metadata
