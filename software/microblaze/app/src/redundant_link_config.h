#ifndef REDUNDANT_LINK_CONFIG_H
#define REDUNDANT_LINK_CONFIG_H

/*
 * Health / Failover 정책
 */
#define RL_FAIL_THRESHOLD                 3U
#define RL_RECOVERY_COUNT                 5U
#define RL_PREFERRED_CHANNEL_A            0U

/*
 * 100 MHz 기준
 * - Pair Wait Timeout : 10 ms
 * - Channel Timeout   : 300 ms
 */
#define RL_PAIR_WAIT_TIMEOUT_CYCLES       1000000U
#define RL_CHANNEL_TIMEOUT_CYCLES         30000000U

/*
 * 출력 Frame Identity Mapping
 *
 * 송신 STM32가 아래 값으로 Frame을 만든다는 기준입니다.
 * RTL은 출력 DEVICE_ID와 CMD를 이 설정값으로 다시 넣고 CRC를 재계산합니다.
 * 입력값과 설정값이 같으므로 결과적으로 필드 값은 변경되지 않습니다.
 */
#define RL_OUTPUT_DEVICE_ID               0x01U
#define RL_COMMAND_MAP_0_VALUE            0x10U
#define RL_COMMAND_MAP_1_VALUE            0x11U
#define RL_COMMAND_MAP_2_VALUE            0x12U
#define RL_COMMAND_MAP_3_VALUE            0x13U

#endif /* REDUNDANT_LINK_CONFIG_H */
