# Representative waveform captures

These images were rendered directly from the final Vivado 2024.2 XSim VCD:
`reports/voltage_display_ip.vcd`.

| Capture | ADC code | Captured millivolts | XSim interval |
|---|---:|---:|---:|
| `0_000.png` | 0 | 0 | 5.205-5.285 us |
| `0_330.png` | 409 | 330 | 5.285-5.365 us |
| `1_650.png` | 2048 | 1650 | 5.365-5.445 us |
| `2_500.png` | 3102 | 2500 | 5.445-5.525 us |
| `3_300.png` | 4095 | 3300 | 5.525-5.605 us |
| `invalid_dashes.png` | 3102 | 2500, ignored | 6.005-6.085 us |

Each capture spans one four-digit scan frame. `an[3:0]` is active-low and
scans `1110`, `1101`, `1011`, `0111`; `seg[6:0]` uses active-low
`{g,f,e,d,c,b,a}` ordering. `dp` is also active-low. The invalid capture shows
four dashes and `dp=1` for every digit.
