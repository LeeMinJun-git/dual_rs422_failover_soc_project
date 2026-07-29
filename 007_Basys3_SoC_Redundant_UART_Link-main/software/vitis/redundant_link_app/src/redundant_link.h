#ifndef REDUNDANT_LINK_H
#define REDUNDANT_LINK_H

#include "xil_types.h"
#include "xparameters.h"

/*
 * Custom IP Base Address
 * 현재 Address Editor 값은 0x00010000입니다.
 */
#ifdef XPAR_REDUNDANT_LINK_CORE_0_BASEADDR
#define RL_BASE_ADDR \
    ((UINTPTR)XPAR_REDUNDANT_LINK_CORE_0_BASEADDR)
#else
#define RL_BASE_ADDR ((UINTPTR)0x00010000U)
#endif

/* AXI4-Lite Register Offset */
#define RL_REG_CONTROL                    0x00U
#define RL_REG_STATUS                     0x04U
#define RL_REG_FAILOVER_CONFIG            0x08U
#define RL_REG_PAIR_WAIT_TIMEOUT          0x0CU
#define RL_REG_CHANNEL_TIMEOUT            0x10U
#define RL_REG_OUTPUT_DEVICE_ID           0x14U
#define RL_REG_COMMAND_MAP_0              0x18U
#define RL_REG_COMMAND_MAP_1              0x1CU
#define RL_REG_COMMAND_MAP_2              0x20U
#define RL_REG_COMMAND_MAP_3              0x24U
#define RL_REG_IRQ_ENABLE                 0x28U
#define RL_REG_IRQ_STATUS                 0x2CU
#define RL_REG_EVENT_FIFO_STATUS          0x30U
#define RL_REG_EVENT_DATA_LOW             0x34U
#define RL_REG_EVENT_DATA_HIGH            0x38U
#define RL_REG_EVENT_FIFO_CONTROL         0x3CU
#define RL_REG_EVENT_LOST_COUNT           0x40U

/* CONTROL */
#define RL_CTRL_SYSTEM_ENABLE             (1U << 0)
#define RL_CTRL_STATISTICS_CLEAR          (1U << 1)
#define RL_CTRL_EVENT_FIFO_CLEAR          (1U << 2)

/* STATUS */
#define RL_STATUS_SYSTEM_ENABLE           (1U << 0)
#define RL_STATUS_CHANNEL_A_ALIVE         (1U << 1)
#define RL_STATUS_CHANNEL_B_ALIVE         (1U << 2)
#define RL_STATUS_PREFERRED_B             (1U << 3)
#define RL_STATUS_LAST_SELECTED_B         (1U << 4)
#define RL_STATUS_PAIR_WAIT_ACTIVE        (1U << 5)
#define RL_STATUS_OUTPUT_BUSY             (1U << 6)
#define RL_STATUS_EVENT_NOT_EMPTY         (1U << 7)
#define RL_STATUS_FRAME_MISMATCH          (1U << 8)
#define RL_STATUS_BOTH_INVALID            (1U << 9)

/*
 * 상태 변화 로그 대상입니다.
 * PAIR_WAIT, OUTPUT_BUSY, EVENT_NOT_EMPTY는 순간 신호라 제외합니다.
 */
#define RL_STATUS_MONITOR_MASK \
    (RL_STATUS_SYSTEM_ENABLE   | \
     RL_STATUS_CHANNEL_A_ALIVE | \
     RL_STATUS_CHANNEL_B_ALIVE | \
     RL_STATUS_PREFERRED_B     | \
     RL_STATUS_LAST_SELECTED_B | \
     RL_STATUS_FRAME_MISMATCH  | \
     RL_STATUS_BOTH_INVALID)

/* IRQ_ENABLE / IRQ_STATUS */
#define RL_IRQ_EVENT_NOT_EMPTY            (1U << 0)
#define RL_IRQ_EVENT_LOST                 (1U << 1)
#define RL_IRQ_FRAME_MISMATCH             (1U << 2)
#define RL_IRQ_BOTH_INVALID               (1U << 3)
#define RL_IRQ_CHANNEL_FAULT              (1U << 4)
#define RL_IRQ_FIFO_UNDERFLOW             (1U << 5)

#define RL_IRQ_STICKY_MASK                0x0000003EU
#define RL_IRQ_ENABLE_MASK                0x0000003FU

/* EVENT_FIFO_STATUS */
#define RL_FIFO_EMPTY                     (1U << 0)
#define RL_FIFO_FULL                      (1U << 1)
#define RL_FIFO_FRONT_VALID               (1U << 2)
#define RL_FIFO_COUNT_MASK                0x0000FF00U
#define RL_FIFO_COUNT_SHIFT               8U
#define RL_FIFO_UNDERFLOW_MASK            0xFFFF0000U
#define RL_FIFO_UNDERFLOW_SHIFT           16U

/* EVENT_FIFO_CONTROL */
#define RL_FIFO_CONTROL_POP               (1U << 0)
#define RL_FIFO_CONTROL_CLEAR             (1U << 1)

/* Event Channel: Event[23:22] */
#define RL_CHANNEL_SYSTEM                 0U
#define RL_CHANNEL_A                      1U
#define RL_CHANNEL_B                      2U
#define RL_CHANNEL_BOTH                   3U

/* Event Code: Event[31:24] */
#define RL_EV_CRC_ERROR                   0x01U
#define RL_EV_LENGTH_ERROR                0x02U
#define RL_EV_UART_FRAME_ERROR            0x03U
#define RL_EV_SEQ_GAP                     0x04U
#define RL_EV_SEQ_DUP                     0x05U
#define RL_EV_SEQ_OLD                     0x06U
#define RL_EV_CHANNEL_TIMEOUT             0x07U
#define RL_EV_PAIR_TIMEOUT                0x08U
#define RL_EV_PAIR_SEQ_MISMATCH           0x09U
#define RL_EV_PAIR_SEQ_AMBIGUOUS          0x0AU
#define RL_EV_DATA_MISMATCH               0x0BU
#define RL_EV_BOTH_INVALID                0x0CU
#define RL_EV_FRAME_FALLBACK              0x0DU
#define RL_EV_FAILOVER_A_TO_B             0x0EU
#define RL_EV_FAILOVER_B_TO_A             0x0FU
#define RL_EV_RECOVERY_DEFAULT            0x10U
#define RL_EV_OUTPUT_BLOCKED              0x11U
#define RL_EV_UNSUPPORTED_CMD             0x12U
#define RL_EV_FIFO_OVERFLOW               0x13U
#define RL_EV_DUPLICATE_DROP              0x14U
#define RL_EV_INTERBYTE_TIMEOUT           0x15U
#define RL_EV_FRAME_TIMEOUT               0x16U
#define RL_EV_CHANNEL_FAULT               0x17U
#define RL_EV_CHANNEL_RECOVERED           0x18U
#define RL_EV_MAX_CODE                    RL_EV_CHANNEL_RECOVERED

/* Pair/Data Mismatch Detail[5:0] */
#define RL_MISMATCH_SEQ                   (1U << 0)
#define RL_MISMATCH_CRC                   (1U << 1)
#define RL_MISMATCH_PAYLOAD               (1U << 2)
#define RL_MISMATCH_COMMAND               (1U << 3)
#define RL_MISMATCH_DEVICE_ID             (1U << 4)
#define RL_MISMATCH_LENGTH                (1U << 5)

typedef struct {
    u32 timestamp_us;
    u8  code;
    u8  channel;
    u8  sequence;
    u16 detail;
} RedundantLinkEvent;

/* Custom IP 초기화와 설정 검증 */
void redundant_link_init(void);
int  redundant_link_verify_configuration(void);

/* Custom IP IRQ Register 제어 */
void redundant_link_enable_irqs(void);
void redundant_link_disable_irqs(void);
void redundant_link_clear_irq_sticky(void);

/* 상태와 통계 읽기 */
u32  redundant_link_read_status(void);
u32  redundant_link_read_irq_status(void);
u16  redundant_link_read_event_lost_count(void);
u16  redundant_link_read_fifo_underflow_count(void);

/*
 * 디버그/표시 모듈이 Register Readback을 출력할 때 사용합니다.
 * 쓰기는 Driver 내부에서만 수행합니다.
 */
u32  redundant_link_read_register(u32 offset);

/*
 * Hardware Event가 있으면 LOW/HIGH를 복사한 뒤 즉시 POP하고 1을 반환합니다.
 * FIFO가 비었으면 0을 반환합니다.
 */
int  redundant_link_pop_event(RedundantLinkEvent *event);

#endif /* REDUNDANT_LINK_H */
