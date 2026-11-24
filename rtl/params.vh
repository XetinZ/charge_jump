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

// ---- 서보 ----
localparam integer SERVO_PERIOD_US = 20000;   // 50Hz
localparam integer SERVO_MIN_US    = 700;     // 0도 0.7ms (7주차 자료, HS-322HD)
localparam integer SERVO_SLOPE     = 2276;    // 폭 = MIN + (angle*SLOPE)>>8 → 90도 1.5ms, 180도 2.3ms

// ---- 화면 ----
localparam integer SCREEN_H_SUB = 480 * 16;   // 화면 높이 (소수 4비트 단위)

// >>> make_map.py 가 생성하는 구간 (손으로 고치지 않는다)
localparam integer NUM_SCREENS  = 3;
localparam integer START_SCREEN = 0;
localparam integer START_X      = 80;
localparam integer START_Y      = 448;
// <<< make_map.py
