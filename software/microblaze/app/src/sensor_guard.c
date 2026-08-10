#include "sensor_guard.h"
#include "sensor_guard_config.h"

#include "xil_io.h"
#include "xil_printf.h"

#define SG_THRESHOLD_VALUE \
    ((((u32)SG_HIGH_THRESHOLD & 0x0FFFU) << 16) | \
     ((u32)SG_LOW_THRESHOLD & 0x0FFFU))

static void sg_reg_write(u32 offset, u32 value)
{
    Xil_Out32(SG_BASE_ADDR + (UINTPTR)offset, value);
}

static u32 sg_reg_read(u32 offset)
{
    return Xil_In32(SG_BASE_ADDR + (UINTPTR)offset);
}

u32 sensor_guard_read_register(u32 offset)
{
    return sg_reg_read(offset);
}

void sensor_guard_init(void)
{
    /* 설정 중에는 감시를 정지합니다. */
    sg_reg_write(SG_REG_CONTROL, 0U);

    sg_reg_write(SG_REG_THRESHOLD, SG_THRESHOLD_VALUE);
    sg_reg_write(SG_REG_MAX_DELTA, SG_MAX_DELTA);
    sg_reg_write(SG_REG_STALE_LIMIT, SG_STALE_LIMIT_CYCLES);

    /* 통계와 상태를 지운 뒤 감시를 시작합니다. */
    sg_reg_write(SG_REG_CONTROL, SG_CTRL_CLEAR);
    sg_reg_write(SG_REG_CONTROL, SG_CTRL_ENABLE);
}

int sensor_guard_verify_configuration(void)
{
    int ok;

    ok = 1;

    if ((sg_reg_read(SG_REG_CONTROL) & SG_CTRL_ENABLE) == 0U)
        ok = 0;

    if ((sg_reg_read(SG_REG_THRESHOLD) & 0x0FFF0FFFU) !=
        SG_THRESHOLD_VALUE)
        ok = 0;

    if ((sg_reg_read(SG_REG_MAX_DELTA) & 0x0FFFU) != SG_MAX_DELTA)
        ok = 0;

    if (sg_reg_read(SG_REG_STALE_LIMIT) != SG_STALE_LIMIT_CYCLES)
        ok = 0;

    if (sg_reg_read(SG_REG_IP_VERSION) != SG_EXPECTED_IP_VERSION)
        ok = 0;

    return ok;
}

u32 sensor_guard_read_status(void)
{
    return sg_reg_read(SG_REG_STATUS);
}

u16 sensor_guard_read_current_adc(void)
{
    return (u16)(sg_reg_read(SG_REG_CURRENT_ADC) & 0x0FFFU);
}

u32 sensor_guard_read_sample_count(void)
{
    return sg_reg_read(SG_REG_SAMPLE_COUNT);
}

u32 sensor_guard_read_alarm_count(void)
{
    return sg_reg_read(SG_REG_ALARM_COUNT);
}

u32 sensor_guard_adc_to_mv(u16 adc_raw)
{
    u32 adc;

    adc = (u32)adc_raw & 0x0FFFU;

    /* 0~4095 -> 0~3300 mV, nearest-integer rounding */
    return ((adc * 3300U) + 2047U) / 4095U;
}

void sensor_guard_print_registers(void)
{
    u32 threshold;
    u32 min_max;

    threshold = sg_reg_read(SG_REG_THRESHOLD);
    min_max = sg_reg_read(SG_REG_MIN_MAX);

    xil_printf("\r\n[SENSOR GUARD READBACK]\r\n");
    xil_printf(
        "BASE              = 0x%08x\r\n",
        (unsigned int)SG_BASE_ADDR
    );
    xil_printf(
        "CONTROL           = 0x%08x\r\n",
        (unsigned int)sg_reg_read(SG_REG_CONTROL)
    );
    xil_printf(
        "THRESHOLD         = low:%u high:%u\r\n",
        (unsigned int)(threshold & 0x0FFFU),
        (unsigned int)((threshold >> 16) & 0x0FFFU)
    );
    xil_printf(
        "MAX_DELTA         = %u\r\n",
        (unsigned int)(sg_reg_read(SG_REG_MAX_DELTA) & 0x0FFFU)
    );
    xil_printf(
        "STALE_LIMIT       = %u cycles\r\n",
        (unsigned int)sg_reg_read(SG_REG_STALE_LIMIT)
    );
    xil_printf(
        "CURRENT/MIN/MAX   = %u / %u / %u\r\n",
        (unsigned int)(sg_reg_read(SG_REG_CURRENT_ADC) & 0x0FFFU),
        (unsigned int)(min_max & 0x0FFFU),
        (unsigned int)((min_max >> 16) & 0x0FFFU)
    );
    xil_printf(
        "SAMPLE/ALARM CNT  = %u / %u\r\n",
        (unsigned int)sg_reg_read(SG_REG_SAMPLE_COUNT),
        (unsigned int)sg_reg_read(SG_REG_ALARM_COUNT)
    );
    xil_printf(
        "IP_VERSION        = 0x%08x\r\n",
        (unsigned int)sg_reg_read(SG_REG_IP_VERSION)
    );
}

void sensor_guard_print_status(u32 status)
{
    xil_printf(
        "[SENSOR STATUS] en=%u seen=%u display=%u alarm=%u "
        "U/O/D/S=%u/%u/%u/%u\r\n",
        ((status & SG_STATUS_ENABLE) != 0U) ? 1U : 0U,
        ((status & SG_STATUS_DATA_SEEN) != 0U) ? 1U : 0U,
        ((status & SG_STATUS_DISPLAY_VALID) != 0U) ? 1U : 0U,
        ((status & SG_STATUS_SENSOR_ALARM) != 0U) ? 1U : 0U,
        ((status & SG_STATUS_UNDER_ALARM) != 0U) ? 1U : 0U,
        ((status & SG_STATUS_OVER_ALARM) != 0U) ? 1U : 0U,
        ((status & SG_STATUS_DELTA_ALARM) != 0U) ? 1U : 0U,
        ((status & SG_STATUS_STALE_ALARM) != 0U) ? 1U : 0U
    );
}

void sensor_guard_print_summary(void)
{
    u32 min_max;
    u16 current_adc;

    current_adc = sensor_guard_read_current_adc();
    min_max = sg_reg_read(SG_REG_MIN_MAX);

    xil_printf(
        "[SENSOR] adc=%u mV=%u min=%u max=%u delta=%u "
        "samples=%u alarms=%u\r\n",
        (unsigned int)current_adc,
        (unsigned int)sensor_guard_adc_to_mv(current_adc),
        (unsigned int)(min_max & 0x0FFFU),
        (unsigned int)((min_max >> 16) & 0x0FFFU),
        (unsigned int)(sg_reg_read(SG_REG_LAST_DELTA) & 0x0FFFU),
        (unsigned int)sensor_guard_read_sample_count(),
        (unsigned int)sensor_guard_read_alarm_count()
    );
}