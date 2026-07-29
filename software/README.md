# STM32 Firmware

- `sender/`: ADC sampling, frame generation, CRC/sequence, dual-channel transmission, and fault injection
- `receiver/`: selected-frame reception, validation, ADC/voltage restoration, and terminal output

Both directories retain CubeIDE project files, `.ioc`, startup code, linker scripts, HAL/CMSIS drivers, and application sources. `Debug/` build outputs are excluded.
