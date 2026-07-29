#ifndef REDUNDANT_LINK_EVENT_LOG_H
#define REDUNDANT_LINK_EVENT_LOG_H

#include "redundant_link.h"

/* Event Rate Limit과 Health 표시 상태를 초기화합니다. */
void redundant_link_event_log_init(void);

/*
 * Software Queue에서 꺼낸 Event를 처리합니다.
 * 반복 Event는 Rate Limit하고, Fault/Recovery Event는 즉시 출력합니다.
 */
void redundant_link_event_log_process(const RedundantLinkEvent *event);

/* Event 문자열 변환과 원시 출력 */
const char *redundant_link_event_name(u8 code);
const char *redundant_link_channel_name(u8 channel);
void redundant_link_print_event(const RedundantLinkEvent *event);

#endif /* REDUNDANT_LINK_EVENT_LOG_H */
