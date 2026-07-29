#include "redundant_receiver.h"
#include "redundant_rx_frame.h"
#include "usart.h"

#include <stdint.h>
#include <stdio.h>
#include <string.h>

/*
 * STM32 Final Receiver
 *
 * Data input:
 *
 *   USART1 RX
 *     Basys3 selected UART output
 *
 * Terminal:
 *
 *   USART2 TX/RX
 *     ST-LINK Virtual COM Port
 *
 * Receiver responsibilities:
 *
 *   - Receive the Basys3 output frame
 *   - Use redundant_rx_frame for parsing and CRC validation
 *   - Check sequence continuity
 *   - Restore the 12-bit ADC value
 *   - Convert ADC raw data to voltage
 *   - Detect output timeout and recovery
 *   - Print accumulated terminal logs
 */

/* -------------------------------------------------------------------------- */
/* Timing                                                                     */
/* -------------------------------------------------------------------------- */

#define RX_UART_TIMEOUT_MS             1U
#define CONSOLE_RX_TIMEOUT_MS          0U
#define CONSOLE_TX_TIMEOUT_MS          100U

#define LIVE_PERIOD_MS                 1000U
#define OUTPUT_TIMEOUT_MS              500U

#define SUMMARY_HEADER_PERIOD          10U

/* -------------------------------------------------------------------------- */
/* Statistics                                                                 */
/* -------------------------------------------------------------------------- */

static uint32_t valid_frame_count = 0U;
static uint32_t crc_error_count = 0U;
static uint32_t format_error_count = 0U;
static uint32_t sequence_gap_count = 0U;

/* -------------------------------------------------------------------------- */
/* Latest valid frame                                                         */
/* -------------------------------------------------------------------------- */

static uint8_t last_sequence = 0U;
static uint8_t last_sequence_valid = 0U;

static uint16_t latest_adc_raw = 0U;
static uint32_t latest_adc_mv = 0U;
static uint8_t latest_output_valid = 0U;

/* -------------------------------------------------------------------------- */
/* Timeout state                                                              */
/* -------------------------------------------------------------------------- */

static uint32_t last_valid_frame_tick = 0U;
static uint8_t timeout_reported = 0U;

/* -------------------------------------------------------------------------- */
/* Monitor timing                                                             */
/* -------------------------------------------------------------------------- */

static uint32_t monitor_start_tick = 0U;

static uint32_t live_window_start_tick = 0U;
static uint32_t live_window_frame_count = 0U;

static uint32_t summary_row_count = 0U;

/* -------------------------------------------------------------------------- */
/* Terminal mode                                                              */
/* -------------------------------------------------------------------------- */

static uint8_t detail_logging_enabled = 0U;

/* -------------------------------------------------------------------------- */
/* Console output                                                             */
/* -------------------------------------------------------------------------- */

static void console_write(const char *text)
{
    if (text == NULL)
    {
        return;
    }

    (void)HAL_UART_Transmit(
        &huart2,
        (uint8_t *)text,
        (uint16_t)strlen(text),
        CONSOLE_TX_TIMEOUT_MS);
}

static void print_summary_header(void)
{
    console_write(
        "\r\n"
        " UPTIME   RATE      TOTAL   SEQ   ADC   VOLTAGE   STATE      GAP   CRC   FMT\r\n"
        "-------------------------------------------------------------------------------\r\n");
}

static void print_detail_header(void)
{
    console_write(
        "\r\n"
        "========================== DETAIL MODE ON ==========================\r\n"
        "\r\n"
        " FRAME       SEQ   ADC   VOLTAGE   CRC\r\n"
        "------------------------------------------\r\n");
}

static void print_console_help(void)
{
    console_write(
        "\r\n"
        "======================= RECEIVER COMMANDS ==========================\r\n"
        " D : toggle DETAIL mode ON/OFF\r\n"
        " H : show this command help\r\n"
        "====================================================================\r\n");
}

static void print_event(const char *event_text)
{
    if (event_text == NULL)
    {
        return;
    }

    console_write(
        "\r\n"
        ">>> EVENT -----------------------------------------------------------\r\n"
        "    ");

    console_write(event_text);

    console_write(
        "\r\n"
        "---------------------------------------------------------------------\r\n"
        "\r\n");
}

/* -------------------------------------------------------------------------- */
/* ADC voltage conversion                                                     */
/* -------------------------------------------------------------------------- */

static uint32_t adc_raw_to_mv(uint16_t adc_raw)
{
    adc_raw &= 0x0FFFU;

    /*
     * Voltage reference: 3.3 V
     *
     * Rounded conversion:
     *
     *   mV = ADC * 3300 / 4095
     */
    return (
        ((uint32_t)adc_raw * 3300U) + 2047U
    ) / 4095U;
}

/* -------------------------------------------------------------------------- */
/* DETAIL output                                                              */
/* -------------------------------------------------------------------------- */

static void print_detail_log(
    uint8_t sequence,
    uint16_t adc_raw,
    uint32_t adc_mv)
{
    char message[120];

    (void)snprintf(
        message,
        sizeof(message),
        " %09lu   %3u   %4u   %lu.%03lu V   OK\r\n",
        (unsigned long)valid_frame_count,
        (unsigned int)sequence,
        (unsigned int)adc_raw,
        (unsigned long)(adc_mv / 1000U),
        (unsigned long)(adc_mv % 1000U));

    console_write(message);
}

/* -------------------------------------------------------------------------- */
/* Console commands                                                           */
/* -------------------------------------------------------------------------- */

static void process_console_commands(void)
{
    uint8_t command;
    uint32_t now;

    while (HAL_UART_Receive(
               &huart2,
               &command,
               1U,
               CONSOLE_RX_TIMEOUT_MS) == HAL_OK)
    {
        if ((command == 'd') ||
            (command == 'D'))
        {
            detail_logging_enabled =
                (detail_logging_enabled == 0U) ?
                1U :
                0U;

            now = HAL_GetTick();

            /*
             * Restart the one-second rate window
             * whenever the terminal mode changes.
             */
            live_window_start_tick = now;
            live_window_frame_count = 0U;

            if (detail_logging_enabled != 0U)
            {
                print_detail_header();
            }
            else
            {
                console_write(
                    "\r\n"
                    "========================= DETAIL MODE OFF =========================\r\n"
                    "Returning to one-second summary log.\r\n");

                summary_row_count = 0U;
                print_summary_header();
            }
        }
        else if ((command == 'h') ||
                 (command == 'H'))
        {
            print_console_help();

            if (detail_logging_enabled != 0U)
            {
                print_detail_header();
            }
            else
            {
                print_summary_header();
            }
        }
        else
        {
            /*
             * Ignore CR, LF and unrelated characters.
             */
        }
    }
}

/* -------------------------------------------------------------------------- */
/* Parser errors                                                              */
/* -------------------------------------------------------------------------- */

static void handle_crc_error(
    const RedundantRxFrame *frame)
{
    char event_message[180];

    ++crc_error_count;

    (void)snprintf(
        event_message,
        sizeof(event_message),
        "CRC ERROR : seq=%u calc=%04X received=%04X total=%lu",
        (unsigned int)frame->sequence,
        (unsigned int)frame->calculated_crc,
        (unsigned int)frame->received_crc,
        (unsigned long)crc_error_count);

    print_event(event_message);
}

static void handle_format_error(
    const RedundantRxFrame *frame)
{
    char event_message[180];

    ++format_error_count;

    switch (frame->error_reason)
    {
        case REDUNDANT_RX_ERROR_INVALID_LENGTH:

            (void)snprintf(
                event_message,
                sizeof(event_message),
                "INVALID LENGTH : LEN=%u total=%lu",
                (unsigned int)frame->length,
                (unsigned long)format_error_count);

            break;

        case REDUNDANT_RX_ERROR_UNEXPECTED_FIELDS:

            (void)snprintf(
                event_message,
                sizeof(event_message),
                "FORMAT ERROR : LEN=%u ID=%02X CMD=%02X total=%lu",
                (unsigned int)frame->length,
                (unsigned int)frame->device_id,
                (unsigned int)frame->command,
                (unsigned long)format_error_count);

            break;

        case REDUNDANT_RX_ERROR_ADC_RESERVED_BITS:

            (void)snprintf(
                event_message,
                sizeof(event_message),
                "FORMAT ERROR : ADC_H reserved bits are not zero, value=%02X total=%lu",
                (unsigned int)frame->adc_high_raw,
                (unsigned long)format_error_count);

            break;

        default:

            (void)snprintf(
                event_message,
                sizeof(event_message),
                "FORMAT ERROR : unknown reason, total=%lu",
                (unsigned long)format_error_count);

            break;
    }

    print_event(event_message);
}

/* -------------------------------------------------------------------------- */
/* Valid frame handling                                                       */
/* -------------------------------------------------------------------------- */

static void handle_valid_frame(
    const RedundantRxFrame *frame)
{
    uint8_t expected_sequence;
    uint8_t was_timed_out;

    uint32_t adc_mv;

    char event_message[180];

    adc_mv =
        adc_raw_to_mv(
            frame->adc_raw);

    /* ---------------------------------------------------------------------- */
    /* Sequence continuity                                                    */
    /* ---------------------------------------------------------------------- */

    if (last_sequence_valid != 0U)
    {
        expected_sequence =
            (uint8_t)(last_sequence + 1U);

        if (frame->sequence != expected_sequence)
        {
            ++sequence_gap_count;

            (void)snprintf(
                event_message,
                sizeof(event_message),
                "SEQUENCE GAP : expected=%u received=%u total=%lu",
                (unsigned int)expected_sequence,
                (unsigned int)frame->sequence,
                (unsigned long)sequence_gap_count);

            print_event(event_message);
        }
    }

    /*
     * Save the timeout state before clearing it.
     * The first valid frame after timeout becomes recovery.
     */
    was_timed_out = timeout_reported;

    /* ---------------------------------------------------------------------- */
    /* Save latest valid output                                               */
    /* ---------------------------------------------------------------------- */

    last_sequence = frame->sequence;
    last_sequence_valid = 1U;

    latest_adc_raw = frame->adc_raw;
    latest_adc_mv = adc_mv;
    latest_output_valid = 1U;

    last_valid_frame_tick = HAL_GetTick();
    timeout_reported = 0U;

    ++valid_frame_count;
    ++live_window_frame_count;

    /* ---------------------------------------------------------------------- */
    /* Recovery event                                                         */
    /* ---------------------------------------------------------------------- */

    if (was_timed_out != 0U)
    {
        (void)snprintf(
            event_message,
            sizeof(event_message),
            "OUTPUT RECOVERED : seq=%u ADC=%u voltage=%lu.%03lu V",
            (unsigned int)frame->sequence,
            (unsigned int)frame->adc_raw,
            (unsigned long)(adc_mv / 1000U),
            (unsigned long)(adc_mv % 1000U));

        print_event(event_message);
    }

    /* ---------------------------------------------------------------------- */
    /* DETAIL mode                                                            */
    /* ---------------------------------------------------------------------- */

    if (detail_logging_enabled != 0U)
    {
        print_detail_log(
            frame->sequence,
            frame->adc_raw,
            adc_mv);
    }
}

/* -------------------------------------------------------------------------- */
/* Parser result handling                                                     */
/* -------------------------------------------------------------------------- */

static void handle_parser_result(
    RedundantRxFrameResult result,
    const RedundantRxFrame *frame)
{
    switch (result)
    {
        case REDUNDANT_RX_FRAME_VALID:

            handle_valid_frame(frame);

            break;

        case REDUNDANT_RX_FRAME_CRC_ERROR:

            handle_crc_error(frame);

            break;

        case REDUNDANT_RX_FRAME_FORMAT_ERROR:

            handle_format_error(frame);

            break;

        case REDUNDANT_RX_FRAME_NONE:
        default:

            break;
    }
}

/* -------------------------------------------------------------------------- */
/* Output timeout                                                             */
/* -------------------------------------------------------------------------- */

static void check_output_timeout(void)
{
    uint32_t now;
    char event_message[120];

    now = HAL_GetTick();

    /*
     * Timeout begins only after at least one
     * valid frame has been received.
     */
    if ((last_sequence_valid != 0U) &&
        (timeout_reported == 0U) &&
        ((uint32_t)(now - last_valid_frame_tick) >=
         OUTPUT_TIMEOUT_MS))
    {
        timeout_reported = 1U;

        (void)snprintf(
            event_message,
            sizeof(event_message),
            "OUTPUT TIMEOUT : no valid frame for %lu ms",
            (unsigned long)OUTPUT_TIMEOUT_MS);

        print_event(event_message);
    }
}

/* -------------------------------------------------------------------------- */
/* One-second summary                                                         */
/* -------------------------------------------------------------------------- */

static void print_live_summary(void)
{
    uint32_t now;
    uint32_t elapsed;
    uint32_t uptime_seconds;
    uint32_t frame_rate;

    const char *state_text;

    char message[180];

    /*
     * DETAIL mode prints each valid frame,
     * so the one-second summary is suppressed.
     */
    if (detail_logging_enabled != 0U)
    {
        return;
    }

    now = HAL_GetTick();

    elapsed =
        (uint32_t)(now - live_window_start_tick);

    if (elapsed < LIVE_PERIOD_MS)
    {
        return;
    }

    uptime_seconds =
        (uint32_t)(now - monitor_start_tick) /
        1000U;

    /*
     * Rounded frame rate:
     *
     *   frames * 1000 / elapsed milliseconds
     */
    frame_rate =
        (
            (live_window_frame_count * 1000U) +
            (elapsed / 2U)
        ) / elapsed;

    /*
     * Reprint the column names every ten rows.
     */
    if ((summary_row_count != 0U) &&
        ((summary_row_count %
          SUMMARY_HEADER_PERIOD) == 0U))
    {
        print_summary_header();
    }

    if (latest_output_valid == 0U)
    {
        (void)snprintf(
            message,
            sizeof(message),
            " %06lus  %4lu  %8lu   %3s  %4s   %7s   %-8s  %4lu  %4lu  %4lu\r\n",
            (unsigned long)uptime_seconds,
            (unsigned long)frame_rate,
            (unsigned long)valid_frame_count,
            "-",
            "-",
            "-",
            "WAITING",
            (unsigned long)sequence_gap_count,
            (unsigned long)crc_error_count,
            (unsigned long)format_error_count);
    }
    else
    {
        state_text =
            (timeout_reported != 0U) ?
            "TIMEOUT" :
            "OK";

        (void)snprintf(
            message,
            sizeof(message),
            " %06lus  %4lu  %8lu   %3u  %4u   %lu.%03lu V   %-8s  %4lu  %4lu  %4lu\r\n",
            (unsigned long)uptime_seconds,
            (unsigned long)frame_rate,
            (unsigned long)valid_frame_count,
            (unsigned int)last_sequence,
            (unsigned int)latest_adc_raw,
            (unsigned long)(latest_adc_mv / 1000U),
            (unsigned long)(latest_adc_mv % 1000U),
            state_text,
            (unsigned long)sequence_gap_count,
            (unsigned long)crc_error_count,
            (unsigned long)format_error_count);
    }

    console_write(message);

    ++summary_row_count;

    live_window_start_tick = now;
    live_window_frame_count = 0U;
}

/* -------------------------------------------------------------------------- */
/* Public functions                                                           */
/* -------------------------------------------------------------------------- */

void RedundantReceiver_Init(void)
{
    uint32_t now;

    RedundantRxFrame_Init();

    valid_frame_count = 0U;
    crc_error_count = 0U;
    format_error_count = 0U;
    sequence_gap_count = 0U;

    last_sequence = 0U;
    last_sequence_valid = 0U;

    latest_adc_raw = 0U;
    latest_adc_mv = 0U;
    latest_output_valid = 0U;

    timeout_reported = 0U;

    detail_logging_enabled = 0U;
    summary_row_count = 0U;

    now = HAL_GetTick();

    monitor_start_tick = now;
    live_window_start_tick = now;
    last_valid_frame_tick = now;

    live_window_frame_count = 0U;

    console_write(
        "\r\n"
        "===============================================================================\r\n"
        "                    REDUNDANT LINK OUTPUT MONITOR\r\n"
        "===============================================================================\r\n"
        " Input    : USART1 RX - Basys3 selected UART output\r\n"
        " Console  : USART2 - ST-LINK Virtual COM Port\r\n"
        " Protocol : A5 5A 05 01 10 SEQ ADC_H ADC_L CRC_H CRC_L\r\n"
        " Display  : One accumulated summary row every second\r\n"
        " Commands : [D] Detail mode   [H] Help\r\n"
        "===============================================================================\r\n");

    print_summary_header();
}

void RedundantReceiver_Process(void)
{
    uint8_t byte;

    RedundantRxFrame frame;
    RedundantRxFrameResult result;

    /*
     * Read and process every currently available
     * byte from the Basys3 output UART.
     */
    while (HAL_UART_Receive(
               &huart1,
               &byte,
               1U,
               RX_UART_TIMEOUT_MS) == HAL_OK)
    {
        result =
            RedundantRxFrame_PushByte(
                byte,
                &frame);

        handle_parser_result(
            result,
            &frame);
    }

    process_console_commands();
    check_output_timeout();
    print_live_summary();
}