# Source Selection Manifest

This repository-ready layout was produced from the uploaded `SoC_Project.zip` without changing source-code contents.

## Canonical source selections

1. **Redundant Link Core**
   - Source: `redundant_link/redundant_link.srcs/sources_1/new/`
   - Reason: this is the later integrated source set used by the final Vivado system.
   - Testbenches: `redundant_link.srcs/sim_1/new/`
   - The older duplicate `redundant_link_rtl_final/` snapshot was not copied.

2. **Sensor Guard IP**
   - Source: `sensor_guard_ip_1_0/`
   - Includes RTL, available testbench, XDC, `component.xml`, and XGUI Tcl.

3. **Voltage Display IP**
   - Source: `voltage_display_ip_final_delivery/voltage_display_ip/`
   - Includes final RTL, simulation, packaging scripts, reports, and package metadata.

4. **Vivado integration**
   - Includes the original `.xpr`, Block Design, XCI configurations, wrapper, board XDC, final XSA,
     and selected final implementation evidence.
   - Vivado caches, generated simulation databases, and full `.runs` directories were excluded.

5. **Vitis**
   - Includes the MicroBlaze V application source and hardware XSA.
   - Platform generation trees, IDE logs, and build outputs were excluded.

6. **STM32**
   - Includes complete Sender and Receiver CubeIDE source projects except `Debug/` outputs.
