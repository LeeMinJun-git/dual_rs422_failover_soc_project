#include "redundant_link.h"
#include "redundant_link_config.h"
#include "xil_io.h"
#include "xil_printf.h"

#define RL_FAILOVER_CONFIG_VALUE \
    ((RL_RECOVERY_COUNT << 16) | \
     (RL_FAIL_THRESHOLD << 8)  | \
     RL_PREFERRED_CHANNEL_A)


static void rl_reg_write(u32 offset, u32 value)
{
    Xil_Out32(
        (UINTPTR)RL_BASE_ADDR + (UINTPTR)offset,
        value
    );
}


static u32 rl_reg_read(u32 offset)
{
    return Xil_In32(
        (UINTPTR)RL_BASE_ADDR + (UINTPTR)offset
    );
}


u32 redundant_link_read_register(u32 offset)
{
    return rl_reg_read(offset);
}


void redundant_link_init(void)
{
    xil_printf("[RL INIT] START\r\n");

    /*
     * 초기 설정 중에는 Custom IP의 CPU IRQ 출력을 차단합니다.
     * RTL 데이터 경로도 system_enable=0으로 정지시킵니다.
     */
    rl_reg_write(
        RL_REG_IRQ_ENABLE,
        0U
    );

    rl_reg_write(
        RL_REG_CONTROL,
        0U
    );

    /*
     * 통계, Latched Status, Event FIFO를 초기화합니다.
     * 해당 비트들은 Write-One-Pulse 방식입니다.
     */
    rl_reg_write(
        RL_REG_CONTROL,
        RL_CTRL_STATISTICS_CLEAR |
        RL_CTRL_EVENT_FIFO_CLEAR
    );

    /*
     * Failover 정책 설정:
     * - Preferred Channel: A
     * - Fail Threshold
     * - Recovery Count
     */
    rl_reg_write(
        RL_REG_FAILOVER_CONFIG,
        RL_FAILOVER_CONFIG_VALUE
    );

    /*
     * A/B Pair 대기시간과 채널 무응답 시간을 설정합니다.
     */
    rl_reg_write(
        RL_REG_PAIR_WAIT_TIMEOUT,
        RL_PAIR_WAIT_TIMEOUT_CYCLES
    );

    rl_reg_write(
        RL_REG_CHANNEL_TIMEOUT,
        RL_CHANNEL_TIMEOUT_CYCLES
    );

    /*
     * 출력 프레임의 Device ID와 허용 Command Map을 설정합니다.
     */
    rl_reg_write(
        RL_REG_OUTPUT_DEVICE_ID,
        RL_OUTPUT_DEVICE_ID
    );

    rl_reg_write(
        RL_REG_COMMAND_MAP_0,
        RL_COMMAND_MAP_0_VALUE
    );

    rl_reg_write(
        RL_REG_COMMAND_MAP_1,
        RL_COMMAND_MAP_1_VALUE
    );

    rl_reg_write(
        RL_REG_COMMAND_MAP_2,
        RL_COMMAND_MAP_2_VALUE
    );

    rl_reg_write(
        RL_REG_COMMAND_MAP_3,
        RL_COMMAND_MAP_3_VALUE
    );

    /*
     * 초기화 중 생성됐을 수 있는 Pending Event와
     * Sticky IRQ 상태를 한 번 더 정리합니다.
     */
    rl_reg_write(
        RL_REG_EVENT_FIFO_CONTROL,
        RL_FIFO_CONTROL_CLEAR
    );

    rl_reg_write(
        RL_REG_IRQ_STATUS,
        RL_IRQ_STICKY_MASK
    );

    /*
     * 모든 설정이 끝난 뒤 RTL 데이터 경로를 활성화합니다.
     */
    rl_reg_write(
        RL_REG_CONTROL,
        RL_CTRL_SYSTEM_ENABLE
    );

    xil_printf("[RL INIT] COMPLETE\r\n");
}


int redundant_link_verify_configuration(void)
{
    int ok;

    xil_printf("[RL VERIFY] START\r\n");

    ok = 1;

    if ((rl_reg_read(RL_REG_CONTROL) &
         RL_CTRL_SYSTEM_ENABLE) == 0U) {

        xil_printf(
            "[RL VERIFY] CONTROL mismatch\r\n"
        );

        ok = 0;
    }

    if ((rl_reg_read(RL_REG_FAILOVER_CONFIG) &
         0x00FFFF01U) != RL_FAILOVER_CONFIG_VALUE) {

        xil_printf(
            "[RL VERIFY] FAILOVER_CONFIG mismatch\r\n"
        );

        ok = 0;
    }

    if (rl_reg_read(RL_REG_PAIR_WAIT_TIMEOUT) !=
        RL_PAIR_WAIT_TIMEOUT_CYCLES) {

        xil_printf(
            "[RL VERIFY] PAIR_WAIT_TIMEOUT mismatch\r\n"
        );

        ok = 0;
    }

    if (rl_reg_read(RL_REG_CHANNEL_TIMEOUT) !=
        RL_CHANNEL_TIMEOUT_CYCLES) {

        xil_printf(
            "[RL VERIFY] CHANNEL_TIMEOUT mismatch\r\n"
        );

        ok = 0;
    }

    if ((rl_reg_read(RL_REG_OUTPUT_DEVICE_ID) & 0xFFU) !=
        RL_OUTPUT_DEVICE_ID) {

        xil_printf(
            "[RL VERIFY] OUTPUT_DEVICE_ID mismatch\r\n"
        );

        ok = 0;
    }

    if ((rl_reg_read(RL_REG_COMMAND_MAP_0) & 0xFFU) !=
        RL_COMMAND_MAP_0_VALUE) {

        xil_printf(
            "[RL VERIFY] COMMAND_MAP_0 mismatch\r\n"
        );

        ok = 0;
    }

    if ((rl_reg_read(RL_REG_COMMAND_MAP_1) & 0xFFU) !=
        RL_COMMAND_MAP_1_VALUE) {

        xil_printf(
            "[RL VERIFY] COMMAND_MAP_1 mismatch\r\n"
        );

        ok = 0;
    }

    if ((rl_reg_read(RL_REG_COMMAND_MAP_2) & 0xFFU) !=
        RL_COMMAND_MAP_2_VALUE) {

        xil_printf(
            "[RL VERIFY] COMMAND_MAP_2 mismatch\r\n"
        );

        ok = 0;
    }

    if ((rl_reg_read(RL_REG_COMMAND_MAP_3) & 0xFFU) !=
        RL_COMMAND_MAP_3_VALUE) {

        xil_printf(
            "[RL VERIFY] COMMAND_MAP_3 mismatch\r\n"
        );

        ok = 0;
    }

    /*
     * main.c에서 redundant_link_enable_irqs() 호출 후
     * 이 검증 함수를 실행하므로 IRQ_ENABLE도 확인합니다.
     */
    if ((rl_reg_read(RL_REG_IRQ_ENABLE) & 0x3FU) !=
        RL_IRQ_ENABLE_MASK) {

        xil_printf(
            "[RL VERIFY] IRQ_ENABLE mismatch\r\n"
        );

        ok = 0;
    }

    xil_printf(
        "[RL VERIFY] %s\r\n",
        (ok != 0) ? "PASS" : "FAIL"
    );

    return ok;
}


void redundant_link_enable_irqs(void)
{
    /*
     * 오래된 Sticky IRQ 원인을 먼저 제거한 뒤
     * 모든 IRQ Source를 활성화합니다.
     */
    redundant_link_clear_irq_sticky();

    rl_reg_write(
        RL_REG_IRQ_ENABLE,
        RL_IRQ_ENABLE_MASK
    );
}


void redundant_link_disable_irqs(void)
{
    rl_reg_write(
        RL_REG_IRQ_ENABLE,
        0U
    );
}


u32 redundant_link_read_status(void)
{
    return rl_reg_read(
        RL_REG_STATUS
    );
}


u32 redundant_link_read_irq_status(void)
{
    return rl_reg_read(
        RL_REG_IRQ_STATUS
    );
}


u16 redundant_link_read_event_lost_count(void)
{
    return (u16)(
        rl_reg_read(RL_REG_EVENT_LOST_COUNT) &
        0xFFFFU
    );
}


u16 redundant_link_read_fifo_underflow_count(void)
{
    u32 fifo_status;

    fifo_status = rl_reg_read(
        RL_REG_EVENT_FIFO_STATUS
    );

    return (u16)(
        (fifo_status & RL_FIFO_UNDERFLOW_MASK) >>
        RL_FIFO_UNDERFLOW_SHIFT
    );
}


void redundant_link_clear_irq_sticky(void)
{
    u32 irq_status;
    u32 sticky;

    irq_status = redundant_link_read_irq_status();

    sticky =
        irq_status &
        RL_IRQ_STICKY_MASK;

    if (sticky != 0U) {
        /*
         * IRQ_STATUS의 Sticky Bit는
         * Write-One-to-Clear 방식입니다.
         */
        rl_reg_write(
            RL_REG_IRQ_STATUS,
            sticky
        );
    }
}


int redundant_link_pop_event(RedundantLinkEvent *event)
{
    u32 fifo_status;
    u32 event_low;
    u32 event_high;

    if (event == 0) {
        return 0;
    }

    fifo_status = rl_reg_read(
        RL_REG_EVENT_FIFO_STATUS
    );

    if ((fifo_status & RL_FIFO_EMPTY) != 0U) {
        return 0;
    }

    if ((fifo_status & RL_FIFO_FRONT_VALID) == 0U) {
        return 0;
    }

    /*
     * FIFO Front Event는 POP 전까지 유지됩니다.
     * LOW/HIGH를 모두 복사한 뒤 POP해야 합니다.
     */
    event_low = rl_reg_read(
        RL_REG_EVENT_DATA_LOW
    );

    event_high = rl_reg_read(
        RL_REG_EVENT_DATA_HIGH
    );

    rl_reg_write(
        RL_REG_EVENT_FIFO_CONTROL,
        RL_FIFO_CONTROL_POP
    );

    event->timestamp_us =
        event_high;

    event->code = (u8)(
        (event_low >> 24) &
        0xFFU
    );

    event->channel = (u8)(
        (event_low >> 22) &
        0x03U
    );

    event->sequence = (u8)(
        (event_low >> 14) &
        0xFFU
    );

    event->detail = (u16)(
        event_low &
        0x3FFFU
    );

    return 1;
}