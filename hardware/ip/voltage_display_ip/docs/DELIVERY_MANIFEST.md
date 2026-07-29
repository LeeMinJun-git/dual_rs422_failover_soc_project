# Delivery manifest

## Required handoff items

| Requirement | Delivered evidence |
|---|---|
| Full Verilog RTL | `rtl/*.v` |
| Self-checking testbench | `sim/tb_voltage_display_ip.v` |
| Simulation log | `reports/simulation_xsim.log` |
| Representative waveforms | `waveforms/*.png` and `reports/voltage_display_ip.vcd` |
| Synthesis log | Synthesis section of `reports/package_voltage_display_ip.log` |
| Utilization report | `reports/utilization_ooc.rpt` |
| Timing report | `reports/timing_summary_ooc.rpt`, `reports/timing_metrics_ooc.txt` |
| OOC checkpoint | `reports/voltage_display_ip_ooc.dcp` |
| Methodology and DRC | `reports/methodology_ooc.rpt`, `reports/drc_ooc.rpt` |
| Packaged IP folder | `packaged_ip/voltage_display_ip_1.0/` |
| IP-XACT component | `packaged_ip/voltage_display_ip_1.0/component.xml` |
| Port/polarity/display README | `README_voltage_display_ip.md` |
| Re-runnable packaging Tcl | `scripts/package_voltage_display_ip.tcl` |
| OOC clock constraint | `scripts/voltage_display_ip_ooc.xdc` |
| Verification summary | `VERIFICATION_STATUS.md`, `reports/validation_summary.txt` |
| Warning inventory and impact | `WARNING_LIST.md` |

## Final pass markers

```text
VOLTAGE_DISPLAY_IP TEST PASS
VOLTAGE_DISPLAY_IP VALIDATION PASS
VOLTAGE_DISPLAY_IP PACKAGE COMPLETE
WNS: 5.708 ns
TNS: 0.000 ns
WHS: 0.339 ns
THS: 0.000 ns
VLNV: user.org:user:voltage_display_ip:1.0
```

The Basys3 FND pin XDC is intentionally excluded. Integration must reuse the
existing top-level `seg_0[6:0]`, `dp_0`, and `an_0[3:0]` ports and board XDC.
