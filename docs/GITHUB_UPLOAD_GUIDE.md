# Recommended GitHub Upload Order

Use these groups as separate commits so the repository history remains readable.

1. `README.md`, `.gitignore`, `docs/`
2. `hardware/ip/redundant_link_core/`
3. `hardware/ip/sensor_guard_ip/`
4. `hardware/ip/voltage_display_ip/`
5. `hardware/vivado/`
6. `software/stm32/`
7. `software/vitis/`

Suggested commit messages:

```text
docs: add project overview and source manifest
feat(fpga): add redundant link core RTL and tests
feat(fpga): add sensor guard custom IP
feat(fpga): add voltage display custom IP
build(vivado): add final SoC block design and constraints
feat(stm32): add sender and receiver firmware
feat(vitis): add MicroBlaze V management application
```
