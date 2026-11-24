// top.v — 핀 연결, 모듈 배선, 딥 스위치 옵션.
//   dip_trig : 0 = ROM 표, 1 = 테일러 급수
//   dip_test : 1 = 고정 값 패킷을 매 프레임 송신 (통신 시험용, 명세 8장)
module top #(
    parameter integer CLK_HZ_OVERRIDE = 0,   // 0 이면 params.vh 의 CLK_HZ (시뮬레이션 단축용)
    // 보드 극성. 교재 확인 후 맞춘다.
    parameter BTN_ACTIVE_LOW = 0,            // 1 = 버튼을 누르면 0
    parameter DIP_ACTIVE_LOW = 0,
    parameter LED_ACTIVE_LOW = 0             // 1 = 0 을 내보내면 켜짐
)(
    input  wire       clk,
    input  wire       btn_charge,
    input  wire       btn_left,
    input  wire       btn_right,
    input  wire       btn_reset,
    input  wire       dip_trig,
    input  wire       dip_test,
    output wire [7:0] led,
    output wire       servo,
    output wire       uart_txd
);
    `include "params.vh"
    localparam integer F_CLK = (CLK_HZ_OVERRIDE > 0) ? CLK_HZ_OVERRIDE : CLK_HZ;

    wire btn_inv = (BTN_ACTIVE_LOW != 0);
    wire dip_inv = (DIP_ACTIVE_LOW != 0);

    // ---- 전원 인가 리셋 (동기) ----
    reg [7:0] por_cnt = 8'd0;
    wire rst = !por_cnt[7];
    always @(posedge clk) if (rst) por_cnt <= por_cnt + 1'b1;

    // ---- 틱 ----
    wire tick_game, tick_us;
    tick_gen #(.CLK_HZ(F_CLK), .TICK_HZ(TICK_HZ)) u_tick (
        .clk(clk), .rst(rst), .tick_game(tick_game), .tick_us(tick_us));

    // ---- 입력 ----
    wire c_lv, c_rise, l_lv, l_rise, r_lv, r_rise, rs_rise;
    input_sync #(.CLK_HZ(F_CLK), .DEBOUNCE_MS(DEBOUNCE_MS)) u_in_c (
        .clk(clk), .rst(rst), .in(btn_charge ^ btn_inv), .level(c_lv), .rise(c_rise), .fall());
    input_sync #(.CLK_HZ(F_CLK), .DEBOUNCE_MS(DEBOUNCE_MS)) u_in_l (
        .clk(clk), .rst(rst), .in(btn_left ^ btn_inv), .level(l_lv), .rise(l_rise), .fall());
    input_sync #(.CLK_HZ(F_CLK), .DEBOUNCE_MS(DEBOUNCE_MS)) u_in_r (
        .clk(clk), .rst(rst), .in(btn_right ^ btn_inv), .level(r_lv), .rise(r_rise), .fall());
    input_sync #(.CLK_HZ(F_CLK), .DEBOUNCE_MS(DEBOUNCE_MS)) u_in_rs (
        .clk(clk), .rst(rst), .in(btn_reset ^ btn_inv), .level(), .rise(rs_rise), .fall());

    // 딥 스위치는 2단 동기화만 한다
    reg [1:0] trig_s, test_s;
    always @(posedge clk) begin
        trig_s <= {trig_s[0], dip_trig ^ dip_inv};
        test_s <= {test_s[0], dip_test ^ dip_inv};
    end
    wire trig_mode = trig_s[1];
    wire test_mode = test_s[1];

    // ---- 게임 코어 + 맵 ROM ----
    wire [13:0] map_addr;
    wire [1:0]  map_data;
    wire        trig_start, trig_done;
    wire signed [13:0] trig_sin, trig_cos;
    wire signed [15:0] gx, gy;
    wire [2:0]  screen;
    wire [5:0]  charge;
    wire [7:0]  angle;
    wire [1:0]  state;
    wire        facing, land, bounce, send;

    map_rom u_map (.clk(clk), .addr(map_addr), .data(map_data));

    game_core u_core (
        .clk(clk), .rst(rst), .tick(tick_game),
        .btn_charge(c_lv), .btn_charge_rise(c_rise),
        .btn_left(l_lv),   .btn_left_rise(l_rise),
        .btn_right(r_lv),  .btn_right_rise(r_rise),
        .btn_reset_rise(rs_rise),
        .map_addr(map_addr), .map_data(map_data),
        .trig_start(trig_start), .trig_sin(trig_sin), .trig_cos(trig_cos), .trig_done(trig_done),
        .x(gx), .y(gy), .screen(screen), .charge(charge), .angle(angle),
        .state(state), .facing(facing), .land(land), .bounce(bounce), .send(send));

    // ---- 삼각함수: 두 버전을 함께 돌리고 스위치로 고른다 ----
    wire signed [13:0] sin_rom, cos_rom, sin_tay, cos_tay;
    wire done_rom, done_tay;
    trig_rom    u_trig_rom (.clk(clk), .rst(rst), .start(trig_start), .angle(angle),
                            .sin(sin_rom), .cos(cos_rom), .done(done_rom));
    trig_taylor u_trig_tay (.clk(clk), .rst(rst), .start(trig_start), .angle(angle),
                            .sin(sin_tay), .cos(cos_tay), .done(done_tay));

    // 계산 도중 스위치가 바뀌어도 꼬이지 않도록 시작 순간의 모드를 잡아 둔다
    reg mode_q;
    always @(posedge clk) if (rst) mode_q <= 1'b0; else if (trig_start) mode_q <= trig_mode;
    assign trig_sin  = mode_q ? sin_tay  : sin_rom;
    assign trig_cos  = mode_q ? cos_tay  : cos_rom;
    assign trig_done = mode_q ? done_tay : done_rom;

    // ---- LED, 서보 ----
    wire [7:0] led_on;
    led_gauge u_led (.clk(clk), .rst(rst), .tick(tick_game),
                     .charging(state == 2'd1), .charge(charge), .led(led_on));
    assign led = LED_ACTIVE_LOW ? ~led_on : led_on;

    servo_pwm #(.PERIOD_US(SERVO_PERIOD_US), .MIN_US(SERVO_MIN_US), .SLOPE(SERVO_SLOPE)) u_servo (
        .clk(clk), .rst(rst), .tick_us(tick_us), .angle(angle), .pwm(servo));

    // ---- 패킷 송신 ----
    wire [7:0] status = {2'b00, bounce, land, trig_mode, facing, state};
    wire [7:0] tx_data;
    wire       tx_valid, tx_ready;

    packet_tx u_pkt (
        .clk(clk), .rst(rst),
        .send  (test_mode ? tick_game : send),
        .x_px  (test_mode ? 16'sd320  : {{4{gx[15]}}, gx[15:4]}),
        .y_px  (test_mode ? 16'sd240  : {{4{gy[15]}}, gy[15:4]}),
        .screen(test_mode ? 3'd0      : screen),
        .charge(test_mode ? 6'd32     : charge),
        .angle (test_mode ? 8'd45     : angle),
        .status(test_mode ? 8'h01     : status),
        .tx_data(tx_data), .tx_valid(tx_valid), .tx_ready(tx_ready), .busy());

    uart_tx #(.CLK_HZ(F_CLK), .BAUD(BAUD)) u_uart (
        .clk(clk), .rst(rst), .data(tx_data), .valid(tx_valid), .ready(tx_ready), .tx(uart_txd));
endmodule
