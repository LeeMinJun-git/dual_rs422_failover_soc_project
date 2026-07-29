#include "redundant_link_debug.h"
#include "xil_printf.h"

void redundant_link_print_status(u32 status)
{
    xil_printf("\r\n[STATUS] 0x%08x\r\n", (unsigned int)status);

    xil_printf(
        "  System Enable : %u\r\n",
        ((status & RL_STATUS_SYSTEM_ENABLE) != 0U) ? 1U : 0U
    );

    xil_printf(
        "  Channel A Rx  : %s\r\n",
        ((status & RL_STATUS_CHANNEL_A_ALIVE) != 0U) ?
        "ALIVE" : "NO RX"
    );

    xil_printf(
        "  Channel B Rx  : %s\r\n",
        ((status & RL_STATUS_CHANNEL_B_ALIVE) != 0U) ?
        "ALIVE" : "NO RX"
    );

    xil_printf(
        "  Preferred     : %s\r\n",
        ((status & RL_STATUS_PREFERRED_B) != 0U) ? "B" : "A"
    );

    xil_printf(
        "  Last Selected : %s\r\n",
        ((status & RL_STATUS_LAST_SELECTED_B) != 0U) ? "B" : "A"
    );

    xil_printf(
        "  Pair Waiting  : %u\r\n",
        ((status & RL_STATUS_PAIR_WAIT_ACTIVE) != 0U) ? 1U : 0U
    );

    xil_printf(
        "  Output Busy   : %u\r\n",
        ((status & RL_STATUS_OUTPUT_BUSY) != 0U) ? 1U : 0U
    );

    xil_printf(
        "  Frame Mismatch: %u\r\n",
        ((status & RL_STATUS_FRAME_MISMATCH) != 0U) ? 1U : 0U
    );

    xil_printf(
        "  Both Invalid  : %u\r\n",
        ((status & RL_STATUS_BOTH_INVALID) != 0U) ? 1U : 0U
    );
}

void redundant_link_print_registers(void)
{
    u32 fifo_status;

    fifo_status = redundant_link_read_register(RL_REG_EVENT_FIFO_STATUS);

    xil_printf("\r\n[REGISTER READBACK]\r\n");

    xil_printf(
        "CONTROL          = 0x%08x\r\n",
        (unsigned int)redundant_link_read_register(RL_REG_CONTROL)
    );

    xil_printf(
        "FAILOVER_CONFIG  = 0x%08x\r\n",
        (unsigned int)redundant_link_read_register(RL_REG_FAILOVER_CONFIG)
    );

    xil_printf(
        "PAIR_TIMEOUT     = %u cycles\r\n",
        (unsigned int)redundant_link_read_register(RL_REG_PAIR_WAIT_TIMEOUT)
    );

    xil_printf(
        "CHANNEL_TIMEOUT  = %u cycles\r\n",
        (unsigned int)redundant_link_read_register(RL_REG_CHANNEL_TIMEOUT)
    );

    xil_printf(
        "OUTPUT_DEVICE_ID = 0x%02x\r\n",
        (unsigned int)(
            redundant_link_read_register(RL_REG_OUTPUT_DEVICE_ID) & 0xFFU
        )
    );

    xil_printf(
        "COMMAND_MAP      = %02x %02x %02x %02x\r\n",
        (unsigned int)(redundant_link_read_register(RL_REG_COMMAND_MAP_0) & 0xFFU),
        (unsigned int)(redundant_link_read_register(RL_REG_COMMAND_MAP_1) & 0xFFU),
        (unsigned int)(redundant_link_read_register(RL_REG_COMMAND_MAP_2) & 0xFFU),
        (unsigned int)(redundant_link_read_register(RL_REG_COMMAND_MAP_3) & 0xFFU)
    );

    xil_printf(
        "IRQ_ENABLE       = 0x%02x\r\n",
        (unsigned int)(redundant_link_read_register(RL_REG_IRQ_ENABLE) & 0x3FU)
    );

    xil_printf(
        "EVENT_FIFO       = count:%u underflow:%u lost:%u\r\n",
        (unsigned int)(
            (fifo_status & RL_FIFO_COUNT_MASK) >>
            RL_FIFO_COUNT_SHIFT
        ),
        (unsigned int)(
            (fifo_status & RL_FIFO_UNDERFLOW_MASK) >>
            RL_FIFO_UNDERFLOW_SHIFT
        ),
        (unsigned int)redundant_link_read_event_lost_count()
    );
}
