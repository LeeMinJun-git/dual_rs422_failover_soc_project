#include "redundant_rx_frame.h"

#include <stdint.h>
#include <string.h>

/* -------------------------------------------------------------------------- */
/* Protocol                                                                   */
/* -------------------------------------------------------------------------- */

#define RX_SYNC1                       0xA5U
#define RX_SYNC2                       0x5AU

#define RX_MIN_LENGTH                  3U
#define RX_MAX_LENGTH                  19U

#define RX_EXPECTED_LENGTH             5U
#define RX_EXPECTED_DEVICE_ID          0x01U
#define RX_EXPECTED_COMMAND            0x10U

/* -------------------------------------------------------------------------- */
/* Parser state                                                               */
/* -------------------------------------------------------------------------- */

typedef enum
{
    PARSER_WAIT_SYNC1 = 0,
    PARSER_WAIT_SYNC2,
    PARSER_READ_LENGTH,
    PARSER_READ_BODY,
    PARSER_READ_CRC_H,
    PARSER_READ_CRC_L
} ParserState;

static ParserState parser_state = PARSER_WAIT_SYNC1;

static uint8_t frame_length = 0U;
static uint8_t body[RX_MAX_LENGTH];
static uint8_t body_index = 0U;
static uint8_t received_crc_h = 0U;

/* -------------------------------------------------------------------------- */
/* CRC-16/CCITT-FALSE                                                         */
/* -------------------------------------------------------------------------- */

static uint16_t crc16_ccitt_false(
    const uint8_t *data,
    uint16_t length)
{
    uint16_t crc = 0xFFFFU;
    uint16_t byte_index;
    uint8_t bit_index;

    if ((data == NULL) && (length != 0U))
    {
        return 0U;
    }

    for (byte_index = 0U;
         byte_index < length;
         ++byte_index)
    {
        crc ^=
            (uint16_t)data[byte_index] << 8;

        for (bit_index = 0U;
             bit_index < 8U;
             ++bit_index)
        {
            if ((crc & 0x8000U) != 0U)
            {
                crc =
                    (uint16_t)((crc << 1) ^ 0x1021U);
            }
            else
            {
                crc =
                    (uint16_t)(crc << 1);
            }
        }
    }

    return crc;
}

/* -------------------------------------------------------------------------- */
/* Internal parser reset                                                      */
/* -------------------------------------------------------------------------- */

static void reset_parser(void)
{
    parser_state = PARSER_WAIT_SYNC1;

    frame_length = 0U;
    body_index = 0U;
    received_crc_h = 0U;
}

/* -------------------------------------------------------------------------- */
/* Complete frame validation                                                  */
/* -------------------------------------------------------------------------- */

static RedundantRxFrameResult validate_complete_frame(
    uint8_t received_crc_l,
    RedundantRxFrame *frame)
{
    uint8_t crc_input[1U + RX_MAX_LENGTH];

    if (frame == NULL)
    {
        return REDUNDANT_RX_FRAME_NONE;
    }

    /*
     * CRC input:
     *
     *   LEN + BODY
     */
    crc_input[0] = frame_length;

    memcpy(
        &crc_input[1],
        body,
        frame_length);

    frame->length = frame_length;

    frame->device_id = body[0];
    frame->command = body[1];
    frame->sequence = body[2];

    frame->calculated_crc =
        crc16_ccitt_false(
            crc_input,
            (uint16_t)(1U + frame_length));

    frame->received_crc =
        ((uint16_t)received_crc_h << 8) |
        (uint16_t)received_crc_l;

    /*
     * CRC is checked before the fixed-field format.
     */
    if (frame->calculated_crc !=
        frame->received_crc)
    {
        return REDUNDANT_RX_FRAME_CRC_ERROR;
    }

    if ((frame_length != RX_EXPECTED_LENGTH) ||
        (frame->device_id != RX_EXPECTED_DEVICE_ID) ||
        (frame->command != RX_EXPECTED_COMMAND))
    {
        frame->error_reason =
            REDUNDANT_RX_ERROR_UNEXPECTED_FIELDS;

        return REDUNDANT_RX_FRAME_FORMAT_ERROR;
    }

    frame->adc_high_raw = body[3];
    frame->adc_low_raw = body[4];

    /*
     * ADC_H:
     *
     *   bit 7:4 = reserved, must be zero
     *   bit 3:0 = ADC[11:8]
     */
    if ((frame->adc_high_raw & 0xF0U) != 0U)
    {
        frame->error_reason =
            REDUNDANT_RX_ERROR_ADC_RESERVED_BITS;

        return REDUNDANT_RX_FRAME_FORMAT_ERROR;
    }

    frame->adc_raw =
        ((uint16_t)(frame->adc_high_raw & 0x0FU) << 8) |
        (uint16_t)frame->adc_low_raw;

    return REDUNDANT_RX_FRAME_VALID;
}

/* -------------------------------------------------------------------------- */
/* Public functions                                                           */
/* -------------------------------------------------------------------------- */

void RedundantRxFrame_Init(void)
{
    memset(
        body,
        0,
        sizeof(body));

    reset_parser();
}

RedundantRxFrameResult RedundantRxFrame_PushByte(
    uint8_t byte,
    RedundantRxFrame *frame)
{
    RedundantRxFrameResult result;

    if (frame == NULL)
    {
        return REDUNDANT_RX_FRAME_NONE;
    }

    memset(
        frame,
        0,
        sizeof(*frame));

    result = REDUNDANT_RX_FRAME_NONE;

    switch (parser_state)
    {
        case PARSER_WAIT_SYNC1:

            if (byte == RX_SYNC1)
            {
                parser_state =
                    PARSER_WAIT_SYNC2;
            }

            break;

        case PARSER_WAIT_SYNC2:

            if (byte == RX_SYNC2)
            {
                parser_state =
                    PARSER_READ_LENGTH;
            }
            else if (byte == RX_SYNC1)
            {
                /*
                 * A5 A5 5A:
                 * use the second A5 as the new SYNC1.
                 */
                parser_state =
                    PARSER_WAIT_SYNC2;
            }
            else
            {
                parser_state =
                    PARSER_WAIT_SYNC1;
            }

            break;

        case PARSER_READ_LENGTH:

            if ((byte >= RX_MIN_LENGTH) &&
                (byte <= RX_MAX_LENGTH))
            {
                frame_length = byte;
                body_index = 0U;

                parser_state =
                    PARSER_READ_BODY;
            }
            else
            {
                frame->length = byte;
                frame->error_reason =
                    REDUNDANT_RX_ERROR_INVALID_LENGTH;

                result =
                    REDUNDANT_RX_FRAME_FORMAT_ERROR;

                /*
                 * The invalid length byte itself may be
                 * the first A5 of the next frame.
                 */
                if (byte == RX_SYNC1)
                {
                    frame_length = 0U;
                    body_index = 0U;
                    received_crc_h = 0U;

                    parser_state =
                        PARSER_WAIT_SYNC2;
                }
                else
                {
                    reset_parser();
                }
            }

            break;

        case PARSER_READ_BODY:

            body[body_index] = byte;
            ++body_index;

            if (body_index >= frame_length)
            {
                parser_state =
                    PARSER_READ_CRC_H;
            }

            break;

        case PARSER_READ_CRC_H:

            received_crc_h = byte;

            parser_state =
                PARSER_READ_CRC_L;

            break;

        case PARSER_READ_CRC_L:

            result =
                validate_complete_frame(
                    byte,
                    frame);

            reset_parser();

            break;

        default:

            reset_parser();

            break;
    }

    return result;
}