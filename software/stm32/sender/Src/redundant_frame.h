#ifndef REDUNDANT_FRAME_H
#define REDUNDANT_FRAME_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

/* -------------------------------------------------------------------------- */
/* Frame format                                                               */
/*                                                                            */
/* A5 5A LEN DEVICE_ID CMD SEQ PAYLOAD[0] PAYLOAD[1] CRC_H CRC_L             */
/*                                                                            */
/* LEN = DEVICE_ID(1) + CMD(1) + SEQ(1) + PAYLOAD(2)                         */
/*     = 5                                                                    */
/*                                                                            */
/* ADC payload convention                                                     */
/*   PAYLOAD[0] = {4'b0000, ADC[11:8]}                                        */
/*   PAYLOAD[1] = ADC[7:0]                                                    */
/* -------------------------------------------------------------------------- */

#define REDUNDANT_FRAME_SYNC1              0xA5U
#define REDUNDANT_FRAME_SYNC2              0x5AU

#define REDUNDANT_FRAME_DEVICE_ID          0x01U
#define REDUNDANT_FRAME_COMMAND_ADC        0x10U

#define REDUNDANT_FRAME_PAYLOAD_LENGTH     2U

#define REDUNDANT_FRAME_LENGTH_FIELD       \
    (3U + REDUNDANT_FRAME_PAYLOAD_LENGTH)

/*
 * Total frame:
 * SYNC1 + SYNC2 + LEN field + LEN bytes + CRC_H + CRC_L
 *
 * 2 + 1 + 5 + 2 = 10 bytes
 */
#define REDUNDANT_FRAME_TOTAL_LENGTH       \
    (2U + 1U + REDUNDANT_FRAME_LENGTH_FIELD + 2U)

/* -------------------------------------------------------------------------- */
/* Public functions                                                           */
/* -------------------------------------------------------------------------- */

/**
 * @brief Calculate CRC-16/CCITT-FALSE.
 *
 * CRC parameters:
 *   Polynomial    : 0x1021
 *   Initial value : 0xFFFF
 *   RefIn         : false
 *   RefOut        : false
 *   XorOut        : 0x0000
 *
 * @param data   Input byte array.
 * @param length Number of bytes.
 *
 * @return Calculated 16-bit CRC.
 *         Returns 0 if data is NULL while length is not zero.
 */
uint16_t RedundantFrame_CalculateCrc(
    const uint8_t *data,
    uint16_t length);

/**
 * @brief Build one complete redundant-link frame.
 *
 * Frame format:
 *   A5 5A 05 01 10 SEQ ADC_H ADC_L CRC_H CRC_L
 *
 * CRC is calculated from LEN through the last payload byte.
 *
 * @param sequence    Frame sequence number.
 * @param payload     Two-byte payload.
 * @param corrupt_crc 0: normal CRC
 *                    1: intentionally corrupt CRC for fault testing
 * @param frame       Destination frame buffer.
 *
 * @return REDUNDANT_FRAME_TOTAL_LENGTH on success.
 *         Returns 0 if payload or frame is NULL.
 */
uint16_t RedundantFrame_Build(
    uint8_t sequence,
    const uint8_t payload[REDUNDANT_FRAME_PAYLOAD_LENGTH],
    uint8_t corrupt_crc,
    uint8_t frame[REDUNDANT_FRAME_TOTAL_LENGTH]);

#ifdef __cplusplus
}
#endif

#endif /* REDUNDANT_FRAME_H */