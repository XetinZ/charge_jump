// game_core.v — 게임 상태 기계 (명세 6.2).
// 60Hz 틱마다 한 번, 여러 클록에 걸쳐 차례로 갱신한다. 곱셈기 1개와 맵 ROM 포트 1개를 돌려 쓴다.
//
// 좌표: x, y 는 부호 있는 12.4 고정소수점, 충돌 상자(16x16)의 왼쪽 위.
//       충돌 판정은 픽셀 정수부로 한다. 상자가 차지하는 픽셀은 [px, px+15] x [py, py+15].
module game_core #(
    // 음수면 params.vh 값을 쓴다 (테스트벤치에서 시험용 맵에 맞춰 덮어쓰기 위함)
    parameter integer OV_NUM_SCREENS  = -1,
    parameter integer OV_START_SCREEN = -1,
    parameter integer OV_START_X      = -1,
    parameter integer OV_START_Y      = -1
)(
    input  wire clk,
    input  wire rst,
    input  wire tick,                 // 60Hz, 1클록 펄스

    // 버튼 (input_sync 출력)
    input  wire btn_charge,
    input  wire btn_charge_rise,
    input  wire btn_left,
    input  wire btn_left_rise,
    input  wire btn_right,
    input  wire btn_right_rise,
    input  wire btn_reset_rise,

    // 맵 ROM (동기 읽기 1클록)
    output wire [13:0] map_addr,
    input  wire [1:0]  map_data,

    // 삼각함수 모듈 (각도는 angle 출력을 그대로 연결)
    output reg         trig_start,
    input  wire signed [13:0] trig_sin,
    input  wire signed [13:0] trig_cos,
    input  wire        trig_done,

    // 상태 출력
    output reg  signed [15:0] x,
    output reg  signed [15:0] y,
    output reg  [2:0]  screen,
    output reg  [5:0]  charge,
    output reg  [7:0]  angle,
    output reg  [1:0]  state,         // 0 대기, 1 차지, 2 공중, 3 클리어
    output wire        facing,        // 1 = 왼쪽 (각도 > 90)
    output reg         land,          // 이번 프레임에 착지
    output reg         bounce,        // 이번 프레임에 벽에 튕김
    output reg         fell,          // 이번 프레임에 아래 화면으로 떨어짐
    output wire        rising,        // 공중에서 올라가는 중 (vy < 0). 뷰어의 그림 선택용
    output reg         send           // 갱신 완료, 패킷 송신 요청 (1클록)
);
    `include "params.vh"

    localparam integer NSCR    = (OV_NUM_SCREENS  < 0) ? NUM_SCREENS  : OV_NUM_SCREENS;
    localparam integer INIT_S  = (OV_START_SCREEN < 0) ? START_SCREEN : OV_START_SCREEN;
    localparam integer INIT_X  = (OV_START_X      < 0) ? START_X      : OV_START_X;
    localparam integer INIT_Y  = (OV_START_Y      < 0) ? START_Y      : OV_START_Y;
    localparam [2:0]   TOP_SCR = NSCR - 1;

    localparam [1:0] ST_IDLE = 2'd0, ST_CHARGE = 2'd1, ST_AIR = 2'd2, ST_CLEAR = 2'd3;
    localparam [1:0] T_EMPTY = 2'd0, T_SOLID = 2'd1, T_GOAL = 2'd2;

    // 갱신 단계
    localparam [4:0]
        P_WAIT  = 5'd0,  P_TICK  = 5'd1,
        P_TRIG  = 5'd2,  P_MULX  = 5'd3,  P_MULY  = 5'd4,
        P_GRAV  = 5'd5,
        P_HX    = 5'd6,  P_H1    = 5'd7,  P_H2    = 5'd8,  P_H3   = 5'd9,
        P_VY    = 5'd10, P_V1    = 5'd11, P_V2    = 5'd12, P_V3   = 5'd13,
        P_GOAL  = 5'd14, P_GOAL2 = 5'd15,
        P_SCR   = 5'd16, P_SEND  = 5'd17,
        P_LK    = 5'd18;

    reg [4:0] phase, lk_ret;

    reg signed [11:0] vx, vy;         // 8.4
    reg signed [15:0] xn, yn;         // 이동 후보 위치
    reg        blk1;                  // 첫 번째 조회점이 막혔는가
    reg [7:0]  speed;                 // 4.4
    reg signed [13:0] sin_q;

    wire signed [11:0] px   = x[15:4];
    wire signed [11:0] py   = y[15:4];
    wire signed [11:0] xnpx = xn[15:4];
    wire signed [11:0] ynpx = yn[15:4];

    assign facing = (angle > 8'd90);
    assign rising = (state == 2'd2) && vy[11];

    // ---------------- 버튼 래치 (틱 사이에 지나간 짧은 누름을 놓치지 않기 위함) ----------------
    reg charge_l, left_l, right_l, reset_l;
    reg [3:0] hold_l, hold_r;         // 누르고 있는 프레임 수 (15에서 포화)

    wire step_l = (btn_left  && (hold_l == 0 || hold_l == ANGLE_REPEAT)) || (left_l  && !btn_left  && hold_l == 0);
    wire step_r = (btn_right && (hold_r == 0 || hold_r == ANGLE_REPEAT)) || (right_l && !btn_right && hold_r == 0);
    wire angle_inc = step_l && !step_r && (angle < ANGLE_MAX);
    wire angle_dec = step_r && !step_l && (angle > 8'd0);
    // 연속 이동 중에는 4프레임째마다 2도 움직여 평균 1.25도/프레임
    reg  [1:0] rep_ph;
    wire repeating = (btn_left && hold_l == ANGLE_REPEAT) || (btn_right && hold_r == ANGLE_REPEAT);
    wire [7:0] angle_amt  = (repeating && rep_ph == 2'd3) ? 8'd2 : 8'd1;
    wire [7:0] angle_up   = (angle + angle_amt > ANGLE_MAX) ? ANGLE_MAX : angle + angle_amt;
    wire [7:0] angle_down = (angle < angle_amt) ? 8'd0 : angle - angle_amt;

    // ---------------- 타일 조회 ----------------
    // lk_px, lk_py 에 픽셀 좌표를 넣고 P_LK 를 거치면 다음 단계에서 tile 이 유효하다.
    reg  signed [11:0] lk_px, lk_py;
    wire signed [7:0]  lk_tx = lk_px[11:4];
    wire signed [7:0]  lk_ty = lk_py[11:4];
    wire lk_xout  = (lk_tx < 0) || (lk_tx > 39);
    wire lk_above = (lk_ty < 0);
    wire lk_below = (lk_ty > 29);
    wire [2:0] lk_scr  = lk_above ? screen + 3'd1 : lk_below ? screen - 3'd1 : screen;
    wire [7:0] lk_tyw  = lk_above ? lk_ty + 8'sd30 : lk_below ? lk_ty - 8'sd30 : lk_ty;
    // 화면 좌우 밖, 맨 위 화면의 위, 맨 아래 화면의 아래는 막힘
    wire lk_solid = lk_xout || (lk_above && screen == TOP_SCR) || (lk_below && screen == 3'd0);
    reg  lk_solid_q;
    always @(posedge clk) lk_solid_q <= lk_solid;

    assign map_addr = {lk_scr, lk_tyw[4:0], lk_tx[5:0]};
    wire [1:0] tile    = lk_solid_q ? T_SOLID : map_data;
    wire       blocked = (tile == T_SOLID);

    // ---------------- 공유 곱셈기 (점프 순간 두 번) ----------------
    reg  signed [9:0]  mul_a;
    reg  signed [13:0] mul_b;
    wire signed [23:0] prod = mul_a * mul_b;
    wire signed [11:0] prod_q = prod[23:12];          // >> 12 (산술 시프트)

    // ---------------- 보조 계산 ----------------
    wire signed [12:0] vy_g   = vy + G_ACC;
    wire signed [11:0] vx_neg = -vx;
    wire vx_pos = !vx[11] && (vx != 0);
    wire vy_pos = !vy[11] && (vy != 0);

    always @(posedge clk) begin
        send       <= 1'b0;
        trig_start <= 1'b0;

        if (rst) begin
            phase  <= P_WAIT;
            state  <= ST_IDLE;
            x      <= INIT_X * 16;
            y      <= INIT_Y * 16;
            screen <= INIT_S;
            vx     <= 0;
            vy     <= 0;
            charge <= 0;
            angle  <= ANGLE_INIT;
            land   <= 1'b0;
            bounce <= 1'b0;
            fell   <= 1'b0;
            rep_ph <= 0;
            hold_l <= 0;
            hold_r <= 0;
            charge_l <= 1'b0; left_l <= 1'b0; right_l <= 1'b0; reset_l <= 1'b0;
        end else begin
            case (phase)
            P_WAIT: if (tick) phase <= P_TICK;

            // ---- 입력 처리와 상태별 분기 ----
            P_TICK: begin
                land   <= 1'b0;
                bounce <= 1'b0;
                fell   <= 1'b0;
                rep_ph <= repeating ? rep_ph + 2'd1 : 2'd0;
                charge_l <= 1'b0; left_l <= 1'b0; right_l <= 1'b0; reset_l <= 1'b0;
                hold_l <= !btn_left  ? 4'd0 : (hold_l == ANGLE_REPEAT) ? hold_l : hold_l + 4'd1;
                hold_r <= !btn_right ? 4'd0 : (hold_r == ANGLE_REPEAT) ? hold_r : hold_r + 4'd1;
                phase  <= P_SEND;

                if (reset_l) begin                       // 리셋 버튼: 시작 위치로
                    state  <= ST_IDLE;
                    x      <= INIT_X * 16;
                    y      <= INIT_Y * 16;
                    screen <= INIT_S;
                    vx     <= 0;
                    vy     <= 0;
                    charge <= 0;
                    angle  <= ANGLE_INIT;
                end else case (state)
                    ST_IDLE: begin
                        if (angle_inc) angle <= angle_up;
                        if (angle_dec) angle <= angle_down;
                        if (btn_charge || charge_l) begin
                            state  <= ST_CHARGE;
                            charge <= 0;
                        end
                    end
                    ST_CHARGE: begin
                        if (angle_inc) angle <= angle_up;
                        if (angle_dec) angle <= angle_down;
                        if (!btn_charge) begin           // 뗐다 → 점프
                            speed      <= SPEED_BASE + {1'b0, charge, 1'b0};
                            trig_start <= 1'b1;
                            phase      <= P_TRIG;
                        end else if (charge != CHARGE_MAX)
                            charge <= charge + 6'd1;
                    end
                    ST_AIR:   phase <= P_GRAV;
                    default:  ;                           // 클리어: 정지
                endcase
            end

            // ---- 점프 초기 속도: vx = (speed*cos)>>12, vy = -(speed*sin)>>12 ----
            P_TRIG: if (trig_done) begin
                mul_a <= {2'b00, speed};
                mul_b <= trig_cos;
                sin_q <= trig_sin;
                phase <= P_MULX;
            end
            P_MULX: begin
                vx    <= prod_q;
                mul_b <= sin_q;
                phase <= P_MULY;
            end
            P_MULY: begin
                vy     <= -prod_q;
                state  <= ST_AIR;
                charge <= 0;
                phase  <= P_SEND;
            end

            // ---- 1. 중력 ----
            P_GRAV: begin
                vy    <= (vy_g > V_TERM) ? V_TERM : vy_g[11:0];
                phase <= P_HX;
            end

            // ---- 2. 가로 이동: 진행 방향 쪽 변의 위·아래 두 점 ----
            P_HX: begin
                xn    <= x + {{4{vx[11]}}, vx};
                phase <= (vx == 0) ? P_VY : P_H1;
            end
            P_H1: begin
                lk_px  <= vx_pos ? xnpx + 12'sd15 : xnpx;
                lk_py  <= py;
                lk_ret <= P_H2;
                phase  <= P_LK;
            end
            P_H2: begin
                blk1   <= blocked;
                lk_py  <= py + 12'sd15;
                lk_ret <= P_H3;
                phase  <= P_LK;
            end
            P_H3: begin
                if (blk1 || blocked) begin
                    // 타일 경계에 붙이고(소수부 0) 절반 속도로 튕긴다
                    x      <= vx_pos ? {lk_tx - 8'sd1, 8'h00} : {lk_tx + 8'sd1, 8'h00};
                    vx     <= {vx_neg[11], vx_neg[11:1]};
                    bounce <= 1'b1;
                end else
                    x <= xn;
                phase <= P_VY;
            end

            // ---- 3. 세로 이동: 진행 방향 쪽 변의 좌·우 두 점 ----
            P_VY: begin
                yn    <= y + {{4{vy[11]}}, vy};
                phase <= (vy == 0) ? P_GOAL : P_V1;
            end
            P_V1: begin
                lk_px  <= px;
                lk_py  <= vy_pos ? ynpx + 12'sd15 : ynpx;
                lk_ret <= P_V2;
                phase  <= P_LK;
            end
            P_V2: begin
                blk1   <= blocked;
                lk_px  <= px + 12'sd15;
                lk_ret <= P_V3;
                phase  <= P_LK;
            end
            P_V3: begin
                if (blk1 || blocked) begin
                    if (vy_pos) begin                    // 착지
                        y     <= {lk_ty - 8'sd1, 8'h00};
                        vx    <= 0;
                        vy    <= 0;
                        state <= ST_IDLE;
                        land  <= 1'b1;
                    end else begin                       // 천장
                        y  <= {lk_ty + 8'sd1, 8'h00};
                        vy <= 0;
                    end
                end else
                    y <= yn;
                phase <= P_GOAL;
            end

            // ---- 4. 목표 확인: 상자 중심 ----
            P_GOAL: begin
                lk_px  <= px + 12'sd8;
                lk_py  <= py + 12'sd8;
                lk_ret <= P_GOAL2;
                phase  <= P_LK;
            end
            P_GOAL2: begin
                if (tile == T_GOAL) begin
                    state <= ST_CLEAR;
                    vx    <= 0;
                    vy    <= 0;
                end
                phase <= P_SCR;
            end

            // ---- 5. 화면 전환: 상자 중심이 화면 밖으로 ----
            P_SCR: begin
                if (py < -12'sd8 && screen != TOP_SCR) begin
                    screen <= screen + 3'd1;
                    y      <= y + SCREEN_H_SUB;
                end else if (py >= 12'sd472 && screen != 3'd0) begin
                    screen <= screen - 3'd1;
                    y      <= y - SCREEN_H_SUB;
                    fell   <= 1'b1;
                end
                phase <= P_SEND;
            end

            // ---- 6. 송신 요청 ----
            P_SEND: begin
                send  <= 1'b1;
                phase <= P_WAIT;
            end

            // 타일 조회 대기: 이 클록에 ROM 이 주소를 받아들이고, 다음 단계에서 tile 이 유효
            P_LK: phase <= lk_ret;

            default: phase <= P_WAIT;
            endcase

            // 에지 래치 (같은 클록에 지우기와 겹치면 세우기가 이긴다)
            if (btn_charge_rise) charge_l <= 1'b1;
            if (btn_left_rise)   left_l   <= 1'b1;
            if (btn_right_rise)  right_l  <= 1'b1;
            if (btn_reset_rise)  reset_l  <= 1'b1;
        end
    end
endmodule
