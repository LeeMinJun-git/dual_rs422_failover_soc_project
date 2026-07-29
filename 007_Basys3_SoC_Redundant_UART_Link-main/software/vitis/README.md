# Vitis

`redundant_link_app/` contains the final MicroBlaze V application sources used for the hardware demonstration. The application includes Redundant Link Core initialization, Sensor Guard configuration at `0x00020000`, AXI readback verification, AXI INTC setup, event FIFO processing, and terminal monitoring.

Create or refresh the Vitis platform from the final Vivado hardware export, then add this application component to the standalone `microblaze_riscv_0` domain.
