#ifndef SENSOR_GUARD_H
#define SENSOR_GUARD_H

#include "xil_types.h"
#include "xparameters.h"

#ifdef XPAR_SENSOR_GUARD_IP_0_BASEADDR
#define SG_BASE_ADDR \
    ((UINTPTR)XPAR_SENSOR_GUARD_IP_0_BASEADDR)
#else
#define SG_BASE_ADDR ((UINTPTR)0x00020000U)
#endif

/* AXI4-Lite Register Offset */
#define SG_REG_CONTROL                    0x00U
#define SG_REG_THRESHOLD                  0x04U
#define SG_REG_MAX_DELTA                  0x08U
#define SG_REG_STALE_LIMIT                0x0CU
#define SG_REG_CURRENT_ADC                0x10U
#define SG_REG_MIN_MAX                    0x14U
#define SG_REG_STATUS                     0x18U
#define SG_REG_SAMPLE_COUNT               0x1CU
#define SG_REG_ALARM_COUNT                0x20U
#define SG_REG_LAST_DELTA                 0x24U
#define SG_REG_IP_VERSION                 0x28U

/* CONTROL */
#define SG_CTRL_ENABLE                    (1U << 0)
#define SG_CTRL_CLEAR                     (1U << 1)

/* STATUS */
#define SG_STATUS_ENABLE                  (1U << 0)
#define SG_STATUS_DATA_SEEN               (1U << 1)
#define SG_STATUS_DISPLAY_VALID           (1U << 2)
#define SG_STATUS_UNDER_ALARM             (1U << 3)
#define SG_STATUS_OVER_ALARM              (1U << 4)
#define SG_STATUS_DELTA_ALARM             (1U << 5)
#define SG_STATUS_STALE_ALARM             (1U << 6)
#define SG_STATUS_SENSOR_ALARM            (1U << 7)

#define SG_STATUS_MONITOR_MASK \
    (SG_STATUS_ENABLE        | \
     SG_STATUS_DATA_SEEN     | \
     SG_STATUS_DISPLAY_VALID | \
     SG_STATUS_UNDER_ALARM   | \
     SG_STATUS_OVER_ALARM    | \
     SG_STATUS_DELTA_ALARM   | \
     SG_STATUS_STALE_ALARM   | \
     SG_STATUS_SENSOR_ALARM)

void sensor_guard_init(void);
int  sensor_guard_verify_configuration(void);

u32  sensor_guard_read_register(u32 offset);
u32  sensor_guard_read_status(void);
u16  sensor_guard_read_current_adc(void);
u32  sensor_guard_read_sample_count(void);
u32  sensor_guard_read_alarm_count(void);

u32  sensor_guard_adc_to_mv(u16 adc_raw);

void sensor_guard_print_registers(void);
void sensor_guard_print_status(u32 status);
void sensor_guard_print_summary(void);

#endif /* SENSOR_GUARD_H */