# Basys3 SoC Redundant UART Link

Vivado project snapshot for a redundant dual-channel UART/RS-422 link targeting
the Basys3 Artix-7 device (`xc7a35tcpg236-1`).

## Project structure

- `redundant_link.xpr`: Vivado project
- `redundant_link.srcs/sources_1/new/`: synthesizable RTL
- `redundant_link.srcs/sim_1/new/`: self-checking testbenches
- `redundant_link.srcs/constrs_1/new/`: Basys3 pin and timing constraints

The data path includes dual UART receivers, frame parsing, CRC and sequence
checking, frame FIFOs, pair matching, channel health tracking, decision and
duplicate filtering, output buffering, and UART transmission.

The management path includes event arbitration, an event FIFO, AXI4-Lite
registers, interrupt generation, and the Basys3 LED/7-segment status display.

## Register map

The AXI4-Lite register bank uses 32-bit registers at 4-byte-aligned offsets from
`0x00` through `0x40`. See `axi_lite_regs.v` for field definitions.

## Verification status

The final RTL was validated with Vivado 2024.2 in Verilog-2005 mode.

- All Design Sources and 16 self-checking testbenches compile and elaborate
  successfully: 15 standalone module tests plus `tb_redundant_link_core`.
- Simulation result: 16/16 PASS.
- `tb_fail_count_per_transaction` additionally checks the implemented fail-event
  policy: a local CRC error and the following pair-missing result are counted
  separately, and the configured threshold is applied to the event count.
- Out-of-context synthesis, placement, physical optimization, and routing of
  `redundant_link_core` complete with 0 errors and 0 unrouted nets.
- 100 MHz timing passes with WNS `+0.143 ns`, TNS `0.000 ns`,
  WHS `+0.028 ns`, and THS `0.000 ns`.
- DRC reports 0 errors. No inferred latches, multiple drivers, or port/width
  mismatches were detected.
- See [`FIX_REPORT.md`](FIX_REPORT.md) for the validation scope and remaining
  non-blocking out-of-context warnings.

## Generated files

Vivado-generated `.runs`, `.cache`, `.sim`, `.Xil`, and related output
directories are intentionally excluded. Re-run synthesis and implementation
locally to regenerate build products and reports.
