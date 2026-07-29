#ifndef REDUNDANT_LINK_IRQ_H
#define REDUNDANT_LINK_IRQ_H

#include "redundant_link.h"

/* AXI INTC와 CPU Exception Handler를 초기화합니다. */
int redundant_link_irq_init(void);

/* ISR이 남긴 Pending Flag를 확인합니다. */
int redundant_link_irq_is_pending(void);

/*
 * Hardware Event FIFO를 Software Queue로 옮기고,
 * Sticky IRQ를 Clear한 뒤 AXI INTC Vector를 다시 Enable합니다.
 */
void redundant_link_irq_service(void);

/* Software Queue에서 Event 1개를 꺼냅니다. */
int redundant_link_irq_pop_software_event(RedundantLinkEvent *event);

/* Software Queue가 가득 차서 버린 Event 수를 반환합니다. */
u32 redundant_link_irq_software_drop_count(void);

/* 현재 연결된 AXI INTC Vector ID를 반환합니다. */
u8 redundant_link_irq_vector_id(void);

#endif /* REDUNDANT_LINK_IRQ_H */
