#ifndef REDUNDANT_RX_FRAME_H
#define REDUNDANT_RX_FRAME_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

/*
 * Expected output frame:
 *
 *   A5 5A 05 01 10 SEQ ADC_H ADC_L CRC_H CRC_L
 *
 * LEN = 5
 *
 * CRC-16/CCITT-FALSE calculation range:
 *
 *   LEN, DEVICE_ID, CMD, SEQ, ADC_H, ADC_L
 */

typedef enum
{
    REDUNDANT_RX_FRAME_NONE = 0,
    REDUNDANT_RX_FRAME_VALID,
    REDUNDANT_RX_FRAME_CRC_ERROR,
    REDUNDANT_RX_FRAME_FORMAT_ERROR
} RedundantRxFrameResult;

typedef enum
{
    REDUNDANT_RX_ERROR_NONE = 0,
    REDUNDANT_RX_ERROR_INVALID_LENGTH,
    REDUNDANT_RX_ERROR_UNEXPECTED_FIELDS,
    REDUNDANT_RX_ERROR_ADC_RESERVED_BITS
} RedundantRxFrameError;

typedef struct
{
    uint8_t length;
    uint8_t device_id;
    uint8_t command;
    uint8_t sequence;

    uint8_t adc_high_raw;
    uint8_t adc_low_raw;
    uint16_t adc_raw;

    uint16_t calculated_crc;
    uint16_t received_crc;

    RedundantRxFrameError error_reason;
} RedundantRxFrame;

void RedundantRxFrame_Init(void);

RedundantRxFrameResult RedundantRxFrame_PushByte(
    uint8_t byte,
    RedundantRxFrame *frame);

#ifdef __cplusplus
}
#endif

#endif /* REDUNDANT_RX_FRAME_H */