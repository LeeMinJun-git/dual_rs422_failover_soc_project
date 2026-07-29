# Verification status

Final Vivado run: 2026-07-28 (Asia/Seoul)

## Final result

`voltage_display_ip` passed the required functional simulation, out-of-context
synthesis, 100 MHz setup/hold timing checks, IP-integrity check and IP
packaging flow in Vivado 2024.2.

| Check | Result | Evidence |
|---|---|---|
| Self-checking XSim | PASS | `reports/simulation_xsim.log` |
| Required terminal line | `VOLTAGE_DISPLAY_IP TEST PASS` | `reports/simulation_xsim.log` |
| Exhaustive ADC-to-mV and BCD check | 4096/4096 codes | `sim/tb_voltage_display_ip.v` |
| Target part | `xc7a35tcpg236-1` | `reports/validation_summary.txt` |
| OOC synthesis | PASS | `reports/package_voltage_display_ip.log` |
| Setup timing | WNS `+5.708 ns`, TNS `0.000 ns` | `reports/timing_metrics_ooc.txt` |
| Hold timing | WHS `+0.339 ns`, THS `0.000 ns` | `reports/timing_metrics_ooc.txt` |
| Failing endpoints | Setup 0, Hold 0 | `reports/timing_metrics_ooc.txt` |
| DCP | Generated | `reports/voltage_display_ip_ooc.dcp` |
| IP integrity | PASS | `reports/package_voltage_display_ip.log` |
| VLNV | `user.org:user:voltage_display_ip:1.0` | `component.xml`, validation log |
| Package completion | PASS | `VOLTAGE_DISPLAY_IP PACKAGE COMPLETE` in the package log |
| Errors | 0 emitted error lines | `reports/package_voltage_display_ip.log` |
| Critical warnings | 0 emitted critical-warning lines | `reports/package_voltage_display_ip.log` |

## Functional coverage

The self-checking testbench covers:

- active-high asynchronous reset and FND blanking;
- invalid display using four dashes with the decimal point off;
- all 4096 ADC codes for the rounded conversion formula and all four BCD
  digits;
- representative displays `0.000`, `0.330`, `1.650`, `2.500` and `3.300`;
- decimal fonts 0 through 9, active-low segment patterns, anode order,
  one-active-anode behavior and decimal-point position;
- frame-consistent ADC changes;
- frame-consistent valid-to-invalid transitions within one frame;
- invalid-to-valid recovery; and
- scan recovery after reset.

The XSim VCD is `reports/voltage_display_ip.vcd`. Human-readable captures for
the five representative voltages and the invalid four-dash display are under
`waveforms/`.

## Packaged-IP inspection

The generated `packaged_ip/voltage_display_ip_1.0/component.xml` confirms:

- clock interface `clk`;
- reset interface `reset_p` with `POLARITY=ACTIVE_HIGH`;
- `clk` associated with `reset_p`;
- `FREQ_HZ=100000000`;
- no AXI interface and no memory map;
- synthesis file group containing only the four RTL modules;
- testbench included only in simulation/testbench file groups; and
- relative packaged paths, with no external absolute file reference.

The RTL copies in `rtl/` and `packaged_ip/voltage_display_ip_1.0/src/` are
byte-identical. The testbench copies in `sim/`, packaged `sim/`, and packaged
`src/` are also byte-identical; neither testbench entry belongs to the
synthesis file group.

## Warning disposition

Warnings remain, but none invalidates the completed functional, synthesis,
timing, or IP-integrity result. The generated validation summary reports
`Warnings: 12`; Vivado's `get_msg_config -count` is a message-configuration
count, not the number of warning lines emitted during the run. The actual
runtime log contains 9 warning lines across 6 unique message IDs. Methodology
and DRC report findings are inventoried separately in `WARNING_LIST.md`.

Integration-level pin, I/O-delay, configuration-voltage and full-design DRC
checks remain the responsibility of the top-level Basys3 project because this
IP intentionally excludes the board XDC.

## Scope preservation

No `redundant_link_core`, `status_display.v`, Block Design, project XDC,
bitstream, XSA, Vitis source, branch, commit or pull request was modified.
