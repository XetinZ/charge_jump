// params.vh — 공통 상수 (명세 3장). 모듈 본문 안에서 `include "params.vh" 로 불러 쓴다.
// 값을 바꾸려면 명세서를 먼저 고친다.

// ---- 클록·통신 ----
localparam integer CLK_HZ   = 1_000_000;    // 보드 CLOCK SELECT 를 1MHz 로 둔다 (실습 자료 기준). 1MHz 이상이어야 함
localparam integer BAUD     = 19200;        // 1MHz 에서 115200 은 분주 오차 3.5% 라 쓸 수 없다 (19200: 0.16%)
localparam integer TICK_HZ  = 60;
localparam integer DEBOUNCE_MS = 10;

// ---- 물리 (원시값은 소수 4비트) ----
localparam signed [11:0] G_ACC   = 12'sd8;    // 0.5 px/프레임^2
localparam signed [11:0] V_TERM  = 12'sd240;  // 15 px/프레임
localparam        [7:0]  SPEED_BASE = 8'd64;  // speed = 64 + charge*2
localparam        [5:0]  CHARGE_MAX = 6'd63;

// ---- 각도 ----
localparam [7:0] ANGLE_INIT   = 8'd90;
localparam [7:0] ANGLE_MAX    = 8'd180;
localparam [3:0] ANGLE_REPEAT = 4'd15;        // 이 프레임 수 이상 누르면 연속 이동
// 연속 이동은 4프레임에 5도 (평균 1.25도/프레임 = 초당 75도): 4프레임째마다 2도

// ---- 서보 ----
localparam integer SERVO_PERIOD_US = 20000;   // 50Hz
localparam integer SERVO_MIN_US    = 700;     // 0도 0.7ms (7주차 자료, HS-322HD)
localparam integer SERVO_SLOPE     = 2276;    // 폭 = MIN + (angle*SLOPE)>>8 → 90도 1.5ms, 180도 2.3ms
localparam integer SERVO_REVERSE   = 1;       // 1 = 서보에는 (180 - angle) 을 보낸다 (보드에서 방향이 반대였음)

// ---- 확장 기능 ----
localparam integer TAUNT_FRAMES    = 180;     // 떨어졌을 때 LCD 에 놀림 문구를 띄우는 시간 (3초)
localparam integer SEG_S0_IS_LEFT  = 1;       // 8자리 7-세그먼트: AR_SEG_S0 이 맨 왼쪽 자리면 1

// ---- 우주 스테이지 어둠 기믹 (CDS 조도 센서, ADC AD7908) ----
// 보정 모드(DIP_SW7)에서 8자리 7-세그먼트에 채널별 값이 나온다. CDS 를 가렸다 비췄다 하며 값이 크게 바뀌는 채널을 찾는다
localparam integer DARK_SCREEN = 2;           // 어둠 기믹을 쓰는 화면 (우주)
localparam integer LIGHT_CH    = 0;           // CDS 가 연결된 ADC 채널 (보드에서 확인 후 고칠 것)
localparam integer LIGHT_INV   = 0;           // 밝을수록 값이 작아지면 1
localparam integer LIGHT_T1    = 64;          // (반전 적용 후) 이 값 미만이면 가장 어둡게 (어둠 3)
localparam integer LIGHT_T2    = 128;         //                이 값 미만이면 어둠 2
localparam integer LIGHT_T3    = 192;         //                이 값 미만이면 어둠 1, 이상이면 밝음
localparam integer LIGHT_HYST  = 6;

// ---- 화면 ----
localparam integer SCREEN_H_SUB = 480 * 16;   // 화면 높이 (소수 4비트 단위)

// >>> make_map.py 가 생성하는 구간 (손으로 고치지 않는다)
localparam integer NUM_SCREENS  = 3;
localparam integer START_SCREEN = 0;
localparam integer START_X      = 80;
localparam integer START_Y      = 448;
// <<< make_map.py
