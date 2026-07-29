# Warning inventory and impact

Final run: Vivado 2024.2, 2026-07-28, target `xc7a35tcpg236-1`.

## Confirmed result

- Emitted `ERROR:` lines in the final package log: 0.
- Emitted `CRITICAL WARNING:` lines in the final package log: 0.
- Functional simulation: `VOLTAGE_DISPLAY_IP TEST PASS`.
- OOC setup/hold timing: PASS at 100 MHz.
- IP integrity: PASS.

`reports/validation_summary.txt` contains `Warnings: 12`. This value was
obtained from `get_msg_config -severity WARNING -count`, which counts Vivado
message configurations rather than emitted warning instances. For impact
assessment, use the actual log and report inventories below.

## Runtime package-log warnings

The final `reports/package_voltage_display_ip.log` contains 9 warning lines
across 6 unique message IDs.

| Message | Instances | Meaning | Impact |
|---|---:|---|---|
| `Synth 8-7080` | 1 | Parallel synthesis criteria were not met. | Runtime/performance of the Vivado synthesis process only; no effect on the synthesized circuit. |
| `DRC 23-814` | 2 | Connectivity-based checks are incomplete in OOC mode. | Expected for an isolated IP. Full-project DRC must be run after integration. |
| `IP_Flow 19-11888` | 1 | Initial package description was generic. | Transient during `ipx::package_project`; the final `component.xml` contains the meaningful description `Frame-consistent 0.000-3.300 V Basys3 active-low FND display`. |
| `IP_Flow 19-11770` | 1 | Initial inferred clock interface lacked `FREQ_HZ`. | Transient during initial packaging; final `component.xml` contains `FREQ_HZ=100000000`. |
| `IP_Flow 19-5661` | 2 | Clock interface has no associated bus interface. | Expected: this IP intentionally has no AXI or other bus interface. `clk` is still associated with `reset_p`. |
| `IP_Flow 19-2187` | 2 | Vivado Product Guide file is absent. | Documentation-only. `README_voltage_display_ip.md`, this inventory and the verification report are included. |

The transient description and frequency warnings occur before the Tcl script
finishes assigning the final IP-XACT properties. The later integrity check
passes, and the final `component.xml` was inspected directly.

## DRC report findings

`reports/drc_ooc.rpt` contains 4 warning-severity checks.

| Rule | Checks | Impact |
|---|---:|---|
| `CFGBVS-1` | 1 | Board configuration-voltage properties are top-level project/XDC settings. They are intentionally absent from this reusable IP package. |
| `DPIP-1` | 1 | DSP input is not pipelined. This is an optimization recommendation; the required 100 MHz timing passes with positive slack. |
| `DPOP-1` | 1 | DSP P output register is unused. Optimization/power recommendation only; required timing passes. |
| `DPOP-2` | 1 | DSP multiplier register is unused. Optimization/power recommendation only; required timing passes. |

Adding DSP pipeline stages would change latency and is not necessary for the
specified 100 MHz result.

## Methodology report findings

`reports/methodology_ooc.rpt` contains 38 warning-severity checks.

| Rule | Checks | Impact |
|---|---:|---|
| `DPIR-1` | 12 | The asynchronously reset frame register prevents folding input registers into the DSP block. This affects optimization opportunity, not function; setup and hold timing pass. |
| `TIMING-18` | 26 | OOC ports have no external input/output delays. These delays depend on the surrounding Block Design and Basys3 board constraints, so they must be checked by the integration owner in the full design. |

## Final assessment

The remaining warnings are compatible with an out-of-context, non-AXI,
board-XDC-free IP handoff. None is an Error or Critical Warning, none creates a
failing setup/hold endpoint, and none invalidates the XSim or IP-integrity
passes. Full-project implementation, I/O timing, pin and configuration-voltage
DRC remain required after integration.
