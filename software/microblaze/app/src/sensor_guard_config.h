#ifndef SENSOR_GUARD_CONFIG_H
#define SENSOR_GUARD_CONFIG_H

/*
 * Sensor Guard 정책
 *
 * ADC 기준: 12-bit, 0 ~ 4095, VREF = 3.3 V
 * - Low threshold  : 410  ~= 0.330 V
 * - High threshold : 3685 ~= 2.970 V
 * - Max delta      : 512  ~= 0.413 V/sample
 * - Stale timeout  : 50,000,000 cycles = 500 ms @ 100 MHz
 */
#define SG_LOW_THRESHOLD                  410U
#define SG_HIGH_THRESHOLD                 3685U
#define SG_MAX_DELTA                      512U
#define SG_STALE_LIMIT_CYCLES             50000000U

/* STM32 Sender가 100 ms마다 전송하므로 10 samples ~= 1 second입니다. */
#define SG_SUMMARY_INTERVAL_SAMPLES       10U

#define SG_EXPECTED_IP_VERSION            0x00010000U

#endif /* SENSOR_GUARD_CONFIG_H */