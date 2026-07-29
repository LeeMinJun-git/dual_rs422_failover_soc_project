# Redundant Link Core

Dual UART/RS-422 receive paths, frame validation, sequence monitoring, pair matching,
channel health/failover/recovery, duplicate suppression, event FIFO, AXI4-Lite control,
interrupt generation, status display, and final UART transmission.

- `rtl/`: final RTL used by the integrated Vivado project
- `sim/`: module-level and end-to-end self-checking testbenches
- `package/`: Vivado IP packaging metadata
