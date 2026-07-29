#include "xil_printf.h"
#include "xstatus.h"

#include "redundant_link.h"
#include "redundant_link_irq.h"
#include "redundant_link_event_log.h"
#include "redundant_link_debug.h"

#include "sensor_guard_config.h"
#include "sensor_guard.h"



int main(void)
{
    int interrupt_status;

    u32 status;
    u32 monitored_status;
    u32 last_monitored_status;

    u32 guard_status;
    u32 guard_monitored_status;
    u32 last_guard_monitored_status;
    u32 guard_sample_count;
    u32 last_guard_summary_sample_count;

    u32 software_drop_count;
    u32 last_software_drop_count;
    u16 event_lost_count;
    u16 last_event_lost_count;
    u16 underflow_count;
    u16 last_underflow_count;

    RedundantLinkEvent event;

    redundant_link_event_log_init();

    xil_printf("\r\n");
    xil_printf("========================================\r\n");
    xil_printf(" REDUNDANT LINK FINAL MONITOR START\r\n");
    xil_printf(
        " Link AXI=0x%08x / Guard AXI=0x%08x\r\n",
        (unsigned int)RL_BASE_ADDR,
        (unsigned int)SG_BASE_ADDR
    );
    xil_printf(" Console=9600 8N1 / RS-422 data=115200 8N1\r\n");
    xil_printf("========================================\r\n");

    /* Custom IP 설정 중에는 Peripheral IRQ가 Disable 상태입니다. */
    xil_printf("[BOOT] BEFORE IP INIT\r\n");

    sensor_guard_init();

    redundant_link_init();


    xil_printf("[BOOT] AFTER IP INIT\r\n");

    interrupt_status = redundant_link_irq_init();

    if (interrupt_status != XST_SUCCESS) {
        redundant_link_disable_irqs();

        xil_printf(
            "[FATAL] AXI INTC setup failed: %d\r\n",
            interrupt_status
        );

        while (1) {
        }
    }

    /* AXI INTC와 CPU Handler가 준비된 뒤 Link Core IRQ를 켭니다. */
    redundant_link_enable_irqs();

    redundant_link_print_registers();
    sensor_guard_print_registers();

    if (redundant_link_verify_configuration() != 0)
        xil_printf("[LINK CONFIG] PASS\r\n");
    else {
        redundant_link_disable_irqs();
        xil_printf("[FATAL] LINK CONFIG READBACK FAILED\r\n");

        while (1) {
        }
    }

    if (sensor_guard_verify_configuration() != 0)
        xil_printf("[GUARD CONFIG] PASS\r\n");
    else {
        redundant_link_disable_irqs();
        xil_printf("[FATAL] SENSOR GUARD CONFIG READBACK FAILED\r\n");

        while (1) {
        }
    }

    status = redundant_link_read_status();
    redundant_link_print_status(status);
    last_monitored_status = status & RL_STATUS_MONITOR_MASK;

    guard_status = sensor_guard_read_status();
    sensor_guard_print_status(guard_status);
    last_guard_monitored_status =
        guard_status & SG_STATUS_MONITOR_MASK;

    last_guard_summary_sample_count =
        sensor_guard_read_sample_count();

    last_event_lost_count =
        redundant_link_read_event_lost_count();

    last_underflow_count =
        redundant_link_read_fifo_underflow_count();

    last_software_drop_count =
        redundant_link_irq_software_drop_count();

    xil_printf(
        "\r\n[IRQ] READY vector=%u / waiting for A/B frames...\r\n",
        (unsigned int)redundant_link_irq_vector_id()
    );

    while (1) {
        /*
         * Event FIFO 접근은 IRQ가 알려준 경우에만 수행합니다.
         */
        if (redundant_link_irq_is_pending() != 0) {
            redundant_link_irq_service();

            status = redundant_link_read_status();
            monitored_status = status & RL_STATUS_MONITOR_MASK;

            if (monitored_status != last_monitored_status) {
                xil_printf("\r\n[LINK STATUS CHANGE]\r\n");
                redundant_link_print_status(status);
                last_monitored_status = monitored_status;
            }

            event_lost_count =
                redundant_link_read_event_lost_count();

            if (event_lost_count != last_event_lost_count) {
                xil_printf(
                    "[WARNING] RTL event lost count=%u\r\n",
                    (unsigned int)event_lost_count
                );
                last_event_lost_count = event_lost_count;
            }

            underflow_count =
                redundant_link_read_fifo_underflow_count();

            if (underflow_count != last_underflow_count) {
                xil_printf(
                    "[ERROR] Event FIFO underflow count=%u\r\n",
                    (unsigned int)underflow_count
                );
                last_underflow_count = underflow_count;
            }

            software_drop_count =
                redundant_link_irq_software_drop_count();

            if (software_drop_count != last_software_drop_count) {
                xil_printf(
                    "[WARNING] Software log queue drop count=%u\r\n",
                    (unsigned int)software_drop_count
                );
                last_software_drop_count = software_drop_count;
            }
        }

        /* ISR 밖에서 Software Queue Event를 1개씩 해석합니다. */
        if (redundant_link_irq_pop_software_event(&event) != 0)
            redundant_link_event_log_process(&event);

        /*
         * Sensor Guard에는 별도 IRQ가 없으므로 AXI Status를 Polling합니다.
         * 상태 변화는 즉시 한 줄 출력하고, 정상 값은 10 samples마다 요약합니다.
         */
        guard_status = sensor_guard_read_status();
        guard_monitored_status =
            guard_status & SG_STATUS_MONITOR_MASK;

        if (guard_monitored_status != last_guard_monitored_status) {
            sensor_guard_print_status(guard_status);
            last_guard_monitored_status = guard_monitored_status;
        }

        guard_sample_count = sensor_guard_read_sample_count();

        if ((u32)(guard_sample_count - last_guard_summary_sample_count) >=
            SG_SUMMARY_INTERVAL_SAMPLES) {

            sensor_guard_print_summary();
            last_guard_summary_sample_count = guard_sample_count;
        }
    }

    return 0;
}