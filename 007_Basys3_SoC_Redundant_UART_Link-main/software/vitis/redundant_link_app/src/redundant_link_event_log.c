#include "redundant_link_event_log.h"
#include "xil_printf.h"


#define RL_EVENT_LOG_INTERVAL_US           1000000U
#define RL_EVENT_CHANNEL_COUNT             4U

#define RL_HEALTH_UNKNOWN                  0U
#define RL_HEALTH_OK                       1U
#define RL_HEALTH_FAULT                    2U

static u32 g_event_last_log_us[RL_EV_MAX_CODE + 1U]
                               [RL_EVENT_CHANNEL_COUNT];
static u32 g_event_suppressed_count[RL_EV_MAX_CODE + 1U]
                                     [RL_EVENT_CHANNEL_COUNT];
static u8 g_event_log_initialized[RL_EV_MAX_CODE + 1U]
                                   [RL_EVENT_CHANNEL_COUNT];

static u8 g_channel_a_health;
static u8 g_channel_b_health;

static const char *health_name(u8 health)
{
    if (health == RL_HEALTH_OK)
        return "OK";

    if (health == RL_HEALTH_FAULT)
        return "FAULT";

    return "UNKNOWN";
}

static int event_requires_immediate_log(u8 code)
{
    switch (code) {
        case RL_EV_FAILOVER_A_TO_B:
        case RL_EV_FAILOVER_B_TO_A:
        case RL_EV_RECOVERY_DEFAULT:
        case RL_EV_CHANNEL_FAULT:
        case RL_EV_CHANNEL_RECOVERED:
            return 1;

        default:
            return 0;
    }
}

static void update_health_from_event(const RedundantLinkEvent *event)
{
    int changed;

    changed = 0;

    if (event->code == RL_EV_CHANNEL_FAULT) {
        if (event->channel == RL_CHANNEL_A) {
            g_channel_a_health = RL_HEALTH_FAULT;
            changed = 1;
        }
        else if (event->channel == RL_CHANNEL_B) {
            g_channel_b_health = RL_HEALTH_FAULT;
            changed = 1;
        }
    }
    else if (event->code == RL_EV_CHANNEL_RECOVERED) {
        if (event->channel == RL_CHANNEL_A) {
            g_channel_a_health = RL_HEALTH_OK;
            changed = 1;
        }
        else if (event->channel == RL_CHANNEL_B) {
            g_channel_b_health = RL_HEALTH_OK;
            changed = 1;
        }
    }

    if (changed != 0) {
        xil_printf(
            "[HEALTH] A=%s B=%s\r\n",
            health_name(g_channel_a_health),
            health_name(g_channel_b_health)
        );
    }
}

void redundant_link_event_log_init(void)
{
    u32 code;
    u32 channel;

    for (code = 0U; code <= RL_EV_MAX_CODE; code++) {
        for (channel = 0U;
             channel < RL_EVENT_CHANNEL_COUNT;
             channel++) {

            g_event_last_log_us[code][channel] = 0U;
            g_event_suppressed_count[code][channel] = 0U;
            g_event_log_initialized[code][channel] = 0U;
        }
    }

    g_channel_a_health = RL_HEALTH_UNKNOWN;
    g_channel_b_health = RL_HEALTH_UNKNOWN;
}

void redundant_link_event_log_process(const RedundantLinkEvent *event)
{
    u8 code;
    u8 channel;
    u32 elapsed_us;
    u32 suppressed;

    if (event == 0)
        return;

    code = event->code;
    channel = event->channel;

    if ((code > RL_EV_MAX_CODE) ||
        (channel >= RL_EVENT_CHANNEL_COUNT) ||
        (event_requires_immediate_log(code) != 0)) {

        redundant_link_print_event(event);
        update_health_from_event(event);
        return;
    }

    if (g_event_log_initialized[code][channel] == 0U) {
        g_event_log_initialized[code][channel] = 1U;
        g_event_last_log_us[code][channel] = event->timestamp_us;
        redundant_link_print_event(event);
    }
    else {
        elapsed_us =
            event->timestamp_us - g_event_last_log_us[code][channel];

        if (elapsed_us >= RL_EVENT_LOG_INTERVAL_US) {
            suppressed = g_event_suppressed_count[code][channel];

            if (suppressed != 0U) {
                xil_printf(
                    "[EVENT SUMMARY] %s ch=%s suppressed=%u\r\n",
                    redundant_link_event_name(code),
                    redundant_link_channel_name(channel),
                    (unsigned int)suppressed
                );
            }

            g_event_suppressed_count[code][channel] = 0U;
            g_event_last_log_us[code][channel] = event->timestamp_us;
            redundant_link_print_event(event);
        }
        else {
            if (g_event_suppressed_count[code][channel] != 0xFFFFFFFFU)
                g_event_suppressed_count[code][channel]++;
        }
    }

    update_health_from_event(event);
}


const char *redundant_link_event_name(u8 code)
{
    switch (code) {
        case RL_EV_CRC_ERROR:
            return "CRC_ERROR";
        case RL_EV_LENGTH_ERROR:
            return "LENGTH_ERROR";
        case RL_EV_UART_FRAME_ERROR:
            return "UART_FRAME_ERROR";
        case RL_EV_SEQ_GAP:
            return "SEQ_GAP";
        case RL_EV_SEQ_DUP:
            return "SEQ_DUP";
        case RL_EV_SEQ_OLD:
            return "SEQ_OLD";
        case RL_EV_CHANNEL_TIMEOUT:
            return "CHANNEL_TIMEOUT";
        case RL_EV_PAIR_TIMEOUT:
            return "PAIR_TIMEOUT";
        case RL_EV_PAIR_SEQ_MISMATCH:
            return "PAIR_SEQ_MISMATCH";
        case RL_EV_PAIR_SEQ_AMBIGUOUS:
            return "PAIR_SEQ_AMBIGUOUS";
        case RL_EV_DATA_MISMATCH:
            return "DATA_MISMATCH";
        case RL_EV_BOTH_INVALID:
            return "BOTH_INVALID";
        case RL_EV_FRAME_FALLBACK:
            return "FRAME_FALLBACK";
        case RL_EV_FAILOVER_A_TO_B:
            return "FAILOVER_A_TO_B";
        case RL_EV_FAILOVER_B_TO_A:
            return "FAILOVER_B_TO_A";
        case RL_EV_RECOVERY_DEFAULT:
            return "RECOVERY_DEFAULT";
        case RL_EV_OUTPUT_BLOCKED:
            return "OUTPUT_BLOCKED";
        case RL_EV_UNSUPPORTED_CMD:
            return "UNSUPPORTED_CMD";
        case RL_EV_FIFO_OVERFLOW:
            return "FIFO_OVERFLOW";
        case RL_EV_DUPLICATE_DROP:
            return "DUPLICATE_DROP";
        case RL_EV_INTERBYTE_TIMEOUT:
            return "INTERBYTE_TIMEOUT";
        case RL_EV_FRAME_TIMEOUT:
            return "FRAME_TIMEOUT";
        case RL_EV_CHANNEL_FAULT:
            return "CHANNEL_FAULT";
        case RL_EV_CHANNEL_RECOVERED:
            return "CHANNEL_RECOVERED";
        default:
            return "UNKNOWN_EVENT";
    }
}

const char *redundant_link_channel_name(u8 channel)
{
    switch (channel) {
        case RL_CHANNEL_SYSTEM:
            return "SYSTEM";
        case RL_CHANNEL_A:
            return "A";
        case RL_CHANNEL_B:
            return "B";
        case RL_CHANNEL_BOTH:
            return "BOTH";
        default:
            return "?";
    }
}

static void redundant_link_print_mismatch_flags(u8 flags)
{
    xil_printf(" mismatch=0x%02x [", (unsigned int)flags);

    if ((flags & RL_MISMATCH_LENGTH) != 0U)
        xil_printf(" LEN");

    if ((flags & RL_MISMATCH_DEVICE_ID) != 0U)
        xil_printf(" DEVICE");

    if ((flags & RL_MISMATCH_COMMAND) != 0U)
        xil_printf(" CMD");

    if ((flags & RL_MISMATCH_PAYLOAD) != 0U)
        xil_printf(" PAYLOAD");

    if ((flags & RL_MISMATCH_CRC) != 0U)
        xil_printf(" CRC");

    if ((flags & RL_MISMATCH_SEQ) != 0U)
        xil_printf(" SEQ");

    xil_printf(" ]");
}

void redundant_link_print_event(const RedundantLinkEvent *event)
{
    u8 mismatch_flags;

    if (event == 0)
        return;

    xil_printf(
        "[EVENT t=%u us] %s ch=%s seq=%u",
        (unsigned int)event->timestamp_us,
        redundant_link_event_name(event->code),
        redundant_link_channel_name(event->channel),
        (unsigned int)event->sequence
    );

    switch (event->code) {
        case RL_EV_CRC_ERROR:
            xil_printf(
                " crc_xor=0x%04x",
                (unsigned int)event->detail
            );
            break;

        case RL_EV_LENGTH_ERROR:
            xil_printf(
                " rx_length=0x%02x",
                (unsigned int)(event->detail & 0xFFU)
            );
            break;

        case RL_EV_SEQ_GAP:
        case RL_EV_SEQ_DUP:
        case RL_EV_SEQ_OLD:
            xil_printf(
                " previous_seq=%u",
                (unsigned int)(event->detail & 0xFFU)
            );
            break;

        case RL_EV_PAIR_SEQ_MISMATCH:
        case RL_EV_PAIR_SEQ_AMBIGUOUS:
        case RL_EV_DATA_MISMATCH:
            mismatch_flags = (u8)(event->detail & 0x3FU);
            redundant_link_print_mismatch_flags(mismatch_flags);
            break;

        case RL_EV_CHANNEL_FAULT:
            xil_printf(
                " fail_count=%u",
                (unsigned int)(event->detail & 0xFFU)
            );
            break;

        case RL_EV_FIFO_OVERFLOW:
            xil_printf(
                " raw_full=%u raw_length_error=%u",
                (unsigned int)((event->detail >> 1) & 0x01U),
                (unsigned int)(event->detail & 0x01U)
            );
            break;

        case RL_EV_OUTPUT_BLOCKED:
        case RL_EV_UNSUPPORTED_CMD:
        case RL_EV_DUPLICATE_DROP:
            xil_printf(
                " command=0x%02x",
                (unsigned int)(event->detail & 0xFFU)
            );
            break;

        default:
            if (event->detail != 0U) {
                xil_printf(
                    " detail=0x%04x",
                    (unsigned int)event->detail
                );
            }
            break;
    }

    xil_printf("\r\n");
}
