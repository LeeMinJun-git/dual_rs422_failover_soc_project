#include "redundant_link_irq.h"
#include "xil_exception.h"
#include "xstatus.h"
#include "xintc.h"

/*
 * Vitis 2024.2는 Platform 생성 방식에 따라 XIntc 초기화 인자가
 * Device ID(classic) 또는 Base Address(SDT)가 됩니다.
 */
#ifdef SDT

#if defined(XPAR_XINTC_0_BASEADDR)
#define RL_INTC_INIT_ARG \
    ((UINTPTR)XPAR_XINTC_0_BASEADDR)
#elif defined(XPAR_AXI_INTC_0_BASEADDR)
#define RL_INTC_INIT_ARG \
    ((UINTPTR)XPAR_AXI_INTC_0_BASEADDR)
#elif defined(XPAR_INTC_0_BASEADDR)
#define RL_INTC_INIT_ARG \
    ((UINTPTR)XPAR_INTC_0_BASEADDR)
#else
#error "AXI INTC Base Address macro was not found in xparameters.h"
#endif

#else

#if defined(XPAR_INTC_0_DEVICE_ID)
#define RL_INTC_INIT_ARG \
    ((u16)XPAR_INTC_0_DEVICE_ID)
#elif defined(XPAR_AXI_INTC_0_DEVICE_ID)
#define RL_INTC_INIT_ARG \
    ((u16)XPAR_AXI_INTC_0_DEVICE_ID)
#elif defined(XPAR_XINTC_0_DEVICE_ID)
#define RL_INTC_INIT_ARG \
    ((u16)XPAR_XINTC_0_DEVICE_ID)
#else
/* 현재 Block Design에는 AXI INTC가 1개이므로 classic Device ID는 0입니다. */
#define RL_INTC_INIT_ARG ((u16)0U)
#endif

#endif

/*
 * redundant_link_core_0.irq는 axi_intc_0의 intr[0]에 연결돼 있습니다.
 * BSP가 Vector 매크로를 생성한 경우에는 그 값을 우선 사용합니다.
 */
#if defined(XPAR_INTC_0_REDUNDANT_LINK_CORE_0_IRQ_VEC_ID)
#define RL_INTC_VECTOR_ID \
    ((u8)XPAR_INTC_0_REDUNDANT_LINK_CORE_0_IRQ_VEC_ID)
#elif defined(XPAR_AXI_INTC_0_REDUNDANT_LINK_CORE_0_IRQ_VEC_ID)
#define RL_INTC_VECTOR_ID \
    ((u8)XPAR_AXI_INTC_0_REDUNDANT_LINK_CORE_0_IRQ_VEC_ID)
#elif defined(XPAR_INTC_0_REDUNDANT_LINK_CORE_0_IRQ_INTR)
#define RL_INTC_VECTOR_ID \
    ((u8)XPAR_INTC_0_REDUNDANT_LINK_CORE_0_IRQ_INTR)
#elif defined(XPAR_AXI_INTC_0_REDUNDANT_LINK_CORE_0_IRQ_INTR)
#define RL_INTC_VECTOR_ID \
    ((u8)XPAR_AXI_INTC_0_REDUNDANT_LINK_CORE_0_IRQ_INTR)
#else
#define RL_INTC_VECTOR_ID ((u8)0U)
#endif

/*
 * UARTLite Console이 9600 baud이므로 Hardware FIFO를 먼저 Software Queue로
 * 빠르게 옮기고, 로그는 IRQ 처리 밖에서 출력합니다.
 */
#define RL_SW_EVENT_QUEUE_DEPTH            64U

typedef struct {
    RedundantLinkEvent data[RL_SW_EVENT_QUEUE_DEPTH];
    u16 read_index;
    u16 write_index;
    u16 count;
    u32 dropped_count;
} RedundantLinkSoftwareQueue;

static XIntc g_interrupt_controller;
static volatile u8 g_irq_pending;
static RedundantLinkSoftwareQueue g_event_queue;

static int software_queue_push(const RedundantLinkEvent *event)
{
    if (g_event_queue.count >= RL_SW_EVENT_QUEUE_DEPTH) {
        g_event_queue.dropped_count++;
        return 0;
    }

    g_event_queue.data[g_event_queue.write_index] = *event;

    g_event_queue.write_index++;

    if (g_event_queue.write_index >= RL_SW_EVENT_QUEUE_DEPTH)
        g_event_queue.write_index = 0U;

    g_event_queue.count++;
    return 1;
}

int redundant_link_irq_pop_software_event(RedundantLinkEvent *event)
{
    if ((event == 0) || (g_event_queue.count == 0U))
        return 0;

    *event = g_event_queue.data[g_event_queue.read_index];

    g_event_queue.read_index++;

    if (g_event_queue.read_index >= RL_SW_EVENT_QUEUE_DEPTH)
        g_event_queue.read_index = 0U;

    g_event_queue.count--;
    return 1;
}

/*
 * ISR에서는 UART 출력과 Event 해석을 하지 않습니다.
 * AXI INTC Vector를 잠시 Mask하여 Level IRQ 재진입을 막고 Flag만 남깁니다.
 */
static void redundant_link_irq_handler(void *callback_ref)
{
    XIntc *interrupt_controller;

    interrupt_controller = (XIntc *)callback_ref;

    XIntc_Disable(interrupt_controller, RL_INTC_VECTOR_ID);
    g_irq_pending = 1U;
}

int redundant_link_irq_init(void)
{
    int status;

    g_irq_pending = 0U;
    g_event_queue.read_index = 0U;
    g_event_queue.write_index = 0U;
    g_event_queue.count = 0U;
    g_event_queue.dropped_count = 0U;

    status = XIntc_Initialize(
        &g_interrupt_controller,
        RL_INTC_INIT_ARG
    );

    if (status != XST_SUCCESS)
        return status;

    status = XIntc_Connect(
        &g_interrupt_controller,
        RL_INTC_VECTOR_ID,
        (XInterruptHandler)redundant_link_irq_handler,
        (void *)&g_interrupt_controller
    );

    if (status != XST_SUCCESS)
        return status;

    status = XIntc_Start(
        &g_interrupt_controller,
        XIN_REAL_MODE
    );

    if (status != XST_SUCCESS)
        return status;

    XIntc_Enable(
        &g_interrupt_controller,
        RL_INTC_VECTOR_ID
    );

    Xil_ExceptionInit();

    Xil_ExceptionRegisterHandler(
        XIL_EXCEPTION_ID_INT,
        (Xil_ExceptionHandler)XIntc_InterruptHandler,
        (void *)&g_interrupt_controller
    );

    Xil_ExceptionEnable();

    return XST_SUCCESS;
}

int redundant_link_irq_is_pending(void)
{
    return (g_irq_pending != 0U) ? 1 : 0;
}

/*
 * AXI INTC Vector는 ISR에서 Mask된 상태입니다.
 * Hardware FIFO를 전부 비우고 Sticky 원인을 W1C한 뒤 Vector를 다시 켭니다.
 */
void redundant_link_irq_service(void)
{
    RedundantLinkEvent event;

    while (redundant_link_pop_event(&event) != 0)
        (void)software_queue_push(&event);

    redundant_link_clear_irq_sticky();

    /*
     * Vector가 Mask된 상태라 ISR과 이 대입은 충돌하지 않습니다.
     * 재활성화 직후 새 IRQ가 있으면 ISR이 다시 1로 설정합니다.
     */
    g_irq_pending = 0U;

    XIntc_Enable(
        &g_interrupt_controller,
        RL_INTC_VECTOR_ID
    );
}

u32 redundant_link_irq_software_drop_count(void)
{
    return g_event_queue.dropped_count;
}

u8 redundant_link_irq_vector_id(void)
{
    return RL_INTC_VECTOR_ID;
}
