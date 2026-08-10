#include "redundant_frame.h"

#include <stddef.h>

/* -------------------------------------------------------------------------- */
/* Frame byte indexes                                                         */
/* -------------------------------------------------------------------------- */

#define FRAME_INDEX_SYNC1          0U
#define FRAME_INDEX_SYNC2          1U
#define FRAME_INDEX_LENGTH         2U
#define FRAME_INDEX_DEVICE_ID      3U
#define FRAME_INDEX_COMMAND        4U
#define FRAME_INDEX_SEQUENCE       5U
#define FRAME_INDEX_PAYLOAD        6U

#define FRAME_INDEX_CRC_HIGH       \
    (REDUNDANT_FRAME_TOTAL_LENGTH - 2U)

#define FRAME_INDEX_CRC_LOW        \
    (REDUNDANT_FRAME_TOTAL_LENGTH - 1U)

/* -------------------------------------------------------------------------- */
/* CRC-16/CCITT-FALSE                                                         */
/* -------------------------------------------------------------------------- */

uint16_t RedundantFrame_CalculateCrc(
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
        crc ^= (uint16_t)data[byte_index] << 8;

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
/* Frame builder                                                              */
/* -------------------------------------------------------------------------- */

uint16_t RedundantFrame_Build(
    uint8_t sequence,
    const uint8_t payload[REDUNDANT_FRAME_PAYLOAD_LENGTH],
    uint8_t corrupt_crc,
    uint8_t frame[REDUNDANT_FRAME_TOTAL_LENGTH])
{
    uint16_t crc;
    uint8_t payload_index;

    if ((payload == NULL) || (frame == NULL))
    {
        return 0U;
    }

    /* Fixed header */
    frame[FRAME_INDEX_SYNC1] =
        REDUNDANT_FRAME_SYNC1;

    frame[FRAME_INDEX_SYNC2] =
        REDUNDANT_FRAME_SYNC2;

    frame[FRAME_INDEX_LENGTH] =
        REDUNDANT_FRAME_LENGTH_FIELD;

    frame[FRAME_INDEX_DEVICE_ID] =
        REDUNDANT_FRAME_DEVICE_ID;

    frame[FRAME_INDEX_COMMAND] =
        REDUNDANT_FRAME_COMMAND_ADC;

    frame[FRAME_INDEX_SEQUENCE] =
        sequence;

    /* Payload */
    for (payload_index = 0U;
         payload_index < REDUNDANT_FRAME_PAYLOAD_LENGTH;
         ++payload_index)
    {
        frame[FRAME_INDEX_PAYLOAD + payload_index] =
            payload[payload_index];
    }

    /*
     * CRC calculation range:
     *
     * LEN
     * DEVICE_ID
     * CMD
     * SEQ
     * PAYLOAD[0]
     * PAYLOAD[1]
     *
     * The number of CRC input bytes is:
     * 1-byte LEN field + REDUNDANT_FRAME_LENGTH_FIELD
     */
    crc = RedundantFrame_CalculateCrc(
        &frame[FRAME_INDEX_LENGTH],
        (uint16_t)(1U + REDUNDANT_FRAME_LENGTH_FIELD));

    if (corrupt_crc != 0U)
    {
        /*
         * Fault-injection mode:
         * intentionally invert one CRC bit.
         */
        crc ^= 0x0001U;
    }

    frame[FRAME_INDEX_CRC_HIGH] =
        (uint8_t)(crc >> 8);

    frame[FRAME_INDEX_CRC_LOW] =
        (uint8_t)(crc & 0x00FFU);

    return REDUNDANT_FRAME_TOTAL_LENGTH;
}