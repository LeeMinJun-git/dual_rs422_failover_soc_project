#include "redundant_sender.h"
#include "redundant_frame.h"
#include "usart.h"
#include "adc.h"

#include <stdint.h>
#include <stdio.h>
#include <string.h>

/* -------------------------------------------------------------------------- */
/* Sender configuration                                                       */
/* -------------------------------------------------------------------------- */

#define RS_TX_PERIOD_MS           100U
#define RS_UART_TIMEOUT_MS        20U
#define RS_ADC_TIMEOUT_MS         10U
#define RS_STATUS_PRINT_INTERVAL  10U

typedef enum
{
    RS_MODE_NORMAL = 0,
    RS_MODE_A_BAD_CRC,
    RS_MODE_B_BAD_CRC,
    RS_MODE_A_SILENT,
    RS_MODE_B_SILENT,
    RS_MODE_PAYLOAD_MISMATCH,
    RS_MODE_BOTH_BAD_CRC
} RedundantSenderMode;

static RedundantSenderMode sender_mode = RS_MODE_NORMAL;

static uint8_t sequence_number = 0U;
static uint32_t next_tx_tick = 0U;
static uint32_t transmitted_periods = 0U;

/* -------------------------------------------------------------------------- */
/* Console                                                                    */
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
        RS_UART_TIMEOUT_MS);
}

/* -------------------------------------------------------------------------- */
/* ADC                                                                        */
/* -------------------------------------------------------------------------- */

static HAL_StatusTypeDef read_adc_raw(uint16_t *adc_raw)
{
    HAL_StatusTypeDef status;

    if (adc_raw == NULL)
    {
        return HAL_ERROR;
    }

    status = HAL_ADC_Start(&hadc1);

    if (status != HAL_OK)
    {
        return status;
    }

    status = HAL_ADC_PollForConversion(
        &hadc1,
        RS_ADC_TIMEOUT_MS);

    if (status == HAL_OK)
    {
        *adc_raw =
            (uint16_t)(HAL_ADC_GetValue(&hadc1) & 0x0FFFU);
    }

    (void)HAL_ADC_Stop(&hadc1);

    return status;
}

/* -------------------------------------------------------------------------- */
/* Test mode                                                                  */
/* -------------------------------------------------------------------------- */

static const char *mode_name(RedundantSenderMode mode)
{
    switch (mode)
    {
        case RS_MODE_NORMAL:
            return "NORMAL";

        case RS_MODE_A_BAD_CRC:
            return "A_BAD_CRC";

        case RS_MODE_B_BAD_CRC:
            return "B_BAD_CRC";

        case RS_MODE_A_SILENT:
            return "A_SILENT";

        case RS_MODE_B_SILENT:
            return "B_SILENT";

        case RS_MODE_PAYLOAD_MISMATCH:
            return "PAYLOAD_MISMATCH";

        case RS_MODE_BOTH_BAD_CRC:
            return "BOTH_BAD_CRC";

        default:
            return "UNKNOWN";
    }
}

static void print_help(void)
{
    console_write(
        "\r\n"
        "=== Redundant UART ADC Sender ===\r\n"
        "Frame: A5 5A LEN ID CMD SEQ ADC_H ADC_L CRC_H CRC_L\r\n"
        "LEN  : 5\r\n"
        "CMD  : 0x10\r\n"
        "\r\n"
        "0 : NORMAL, A/B same valid ADC frame\r\n"
        "1 : A_BAD_CRC\r\n"
        "2 : B_BAD_CRC\r\n"
        "3 : A_SILENT\r\n"
        "4 : B_SILENT\r\n"
        "5 : PAYLOAD_MISMATCH, both CRC valid\r\n"
        "6 : BOTH_BAD_CRC\r\n"
        "r : reset sequence to 0\r\n"
        "h : show this help\r\n"
        "\r\n"
        "Mode remains active until another command is entered.\r\n"
        "\r\n");
}

static void set_mode_from_command(uint8_t command)
{
    uint8_t mode_changed = 1U;
    char message[80];

    switch (command)
    {
        case '0':
            sender_mode = RS_MODE_NORMAL;
            break;

        case '1':
            sender_mode = RS_MODE_A_BAD_CRC;
            break;

        case '2':
            sender_mode = RS_MODE_B_BAD_CRC;
            break;

        case '3':
            sender_mode = RS_MODE_A_SILENT;
            break;

        case '4':
            sender_mode = RS_MODE_B_SILENT;
            break;

        case '5':
            sender_mode = RS_MODE_PAYLOAD_MISMATCH;
            break;

        case '6':
            sender_mode = RS_MODE_BOTH_BAD_CRC;
            break;

        case 'r':
        case 'R':
            sequence_number = 0U;
            mode_changed = 0U;

            console_write(
                "[CMD] sequence reset to 0\r\n");
            break;

        case 'h':
        case 'H':
            mode_changed = 0U;
            print_help();
            break;

        case '\r':
        case '\n':
            mode_changed = 0U;
            break;

        default:
            mode_changed = 0U;

            console_write(
                "[CMD] unknown command. Press h for help.\r\n");
            break;
    }

    if (mode_changed != 0U)
    {
        (void)snprintf(
            message,
            sizeof(message),
            "[CMD] mode=%u (%s)\r\n",
            (unsigned int)sender_mode,
            mode_name(sender_mode));

        console_write(message);
    }
}

static void poll_console(void)
{
    uint8_t command;

    if (HAL_UART_Receive(
            &huart2,
            &command,
            1U,
            0U) == HAL_OK)
    {
        set_mode_from_command(command);
    }
}

/* -------------------------------------------------------------------------- */
/* Periodic transmission                                                      */
/* -------------------------------------------------------------------------- */

static void transmit_period(void)
{
uint8_t payload_a[REDUNDANT_FRAME_PAYLOAD_LENGTH];
uint8_t payload_b[REDUNDANT_FRAME_PAYLOAD_LENGTH];

uint8_t frame_a[REDUNDANT_FRAME_TOTAL_LENGTH];
uint8_t frame_b[REDUNDANT_FRAME_TOTAL_LENGTH];

    uint8_t corrupt_a = 0U;
    uint8_t corrupt_b = 0U;

    uint8_t send_a = 1U;
    uint8_t send_b = 1U;

    uint16_t frame_a_length;
    uint16_t frame_b_length;

    uint16_t adc_raw;
    uint32_t adc_mv;

    HAL_StatusTypeDef adc_status;
    HAL_StatusTypeDef status_a = HAL_OK;
    HAL_StatusTypeDef status_b = HAL_OK;

    char message[160];

    /*
     * 한 Sequence에서 ADC를 한 번만 읽는다.
     * 정상 모드에서는 A와 B에 동일한 ADC 값을 넣는다.
     */
    adc_status = read_adc_raw(&adc_raw);

    if (adc_status != HAL_OK)
    {
        (void)snprintf(
            message,
            sizeof(message),
            "[ADC] conversion failed, status=%u\r\n",
            (unsigned int)adc_status);

        console_write(message);
        return;
    }

    /*
     * 12-bit ADC Payload
     *
     * Payload[0] = {4'b0000, ADC[11:8]}
     * Payload[1] = ADC[7:0]
     */
    payload_a[0] =
        (uint8_t)((adc_raw >> 8) & 0x0FU);

    payload_a[1] =
        (uint8_t)(adc_raw & 0x00FFU);

    memcpy(
        payload_b,
        payload_a,
        sizeof(payload_a));

    /*
     * 콘솔 확인용 전압 환산값
     * VREF+ = 3.3V 가정
     */
    adc_mv =
        (((uint32_t)adc_raw * 3300U) + 2047U) /
        4095U;

    switch (sender_mode)
    {
        case RS_MODE_A_BAD_CRC:
            corrupt_a = 1U;
            break;

        case RS_MODE_B_BAD_CRC:
            corrupt_b = 1U;
            break;

        case RS_MODE_A_SILENT:
            send_a = 0U;
            break;

        case RS_MODE_B_SILENT:
            send_b = 0U;
            break;

        case RS_MODE_PAYLOAD_MISMATCH:
            /*
             * B 채널 ADC 값의 최하위 비트만 변경한다.
             * 변경된 Payload 기준으로 B의 CRC를 다시 생성하므로
             * 양쪽 프레임의 CRC 자체는 모두 정상이다.
             */
            payload_b[1] ^= 0x01U;
            break;

        case RS_MODE_BOTH_BAD_CRC:
            corrupt_a = 1U;
            corrupt_b = 1U;
            break;

        case RS_MODE_NORMAL:
        default:
            break;
    }

    frame_a_length = RedundantFrame_Build(
        sequence_number,
        payload_a,
        corrupt_a,
        frame_a);

    frame_b_length = RedundantFrame_Build(
        sequence_number,
        payload_b,
        corrupt_b,
        frame_b);

    if ((frame_a_length == 0U) ||
        (frame_b_length == 0U))
    {
        console_write(
            "[FRAME] frame build failed\r\n");
        return;
    }

    if (send_a != 0U)
    {
        status_a = HAL_UART_Transmit(
            &huart1,
            frame_a,
            frame_a_length,
            RS_UART_TIMEOUT_MS);
    }

    if (send_b != 0U)
    {
        status_b = HAL_UART_Transmit(
            &huart6,
            frame_b,
            frame_b_length,
            RS_UART_TIMEOUT_MS);
    }

    ++transmitted_periods;

    if (((transmitted_periods %
          RS_STATUS_PRINT_INTERVAL) == 0U) ||
        (status_a != HAL_OK) ||
        (status_b != HAL_OK))
    {
        (void)snprintf(
            message,
            sizeof(message),
            "[TX] mode=%u %-16s "
            "seq=%02X ADC=%4u (%4lu mV) "
            "A=%s B=%s\r\n",
            (unsigned int)sender_mode,
            mode_name(sender_mode),
            (unsigned int)sequence_number,
            (unsigned int)adc_raw,
            (unsigned long)adc_mv,
            (send_a == 0U) ?
                "SILENT" :
                ((status_a == HAL_OK) ? "TX" : "ERR"),
            (send_b == 0U) ?
                "SILENT" :
                ((status_b == HAL_OK) ? "TX" : "ERR"));

        console_write(message);
    }

    ++sequence_number;
}

/* -------------------------------------------------------------------------- */
/* Public functions                                                           */
/* -------------------------------------------------------------------------- */

void RedundantSender_Init(void)
{
    sender_mode = RS_MODE_NORMAL;
    sequence_number = 0U;
    transmitted_periods = 0U;

    next_tx_tick =
        HAL_GetTick() + RS_TX_PERIOD_MS;

    print_help();

    console_write(
        "[INIT] sender ready: "
        "A=USART1, B=USART6, console=USART2, ADC=ADC1_IN0\r\n");
}

void RedundantSender_Process(void)
{
    uint32_t now;

    poll_console();

    now = HAL_GetTick();

    if ((int32_t)(now - next_tx_tick) >= 0)
    {
        next_tx_tick += RS_TX_PERIOD_MS;

        /*
         * 디버거 정지 등으로 실행이 오래 지연된 경우
         * 밀린 프레임을 연속 송신하지 않도록 기준 시각을 복구한다.
         */
        if ((int32_t)(now - next_tx_tick) >=
            (int32_t)RS_TX_PERIOD_MS)
        {
            next_tx_tick =
                now + RS_TX_PERIOD_MS;
        }

        transmit_period();
    }
}