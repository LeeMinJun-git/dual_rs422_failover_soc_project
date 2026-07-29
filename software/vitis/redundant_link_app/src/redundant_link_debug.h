#ifndef REDUNDANT_LINK_DEBUG_H
#define REDUNDANT_LINK_DEBUG_H

#include "redundant_link.h"

/* 현재 STATUS와 주요 Register Readback을 UART Console에 출력합니다. */
void redundant_link_print_status(u32 status);
void redundant_link_print_registers(void);

#endif /* REDUNDANT_LINK_DEBUG_H */
