// top.v — 핀 연결, 모듈 배선, 딥 스위치 옵션.
//   dip_trig : 0 = ROM 표, 1 = 테일러 급수
//   dip_test : 1 = 고정 값 패킷을 매 프레임 송신 (통신 시험용, 명세 8장)
//   UART 송신 핀은 딥 스위치 두 개로 고른다. 고르지 않은 핀은 모두 입력(High-Z)이다.
//     dip_uart_port dip_uart_sel   송신 핀
//          0            0          A3 (UART_TXD1, 9핀 시리얼 단자)   ← 기본
//          0            1          A5 (UART_RXD1, 9핀 시리얼 단자)
//          1            0          F6 (USB_TXD0, USB 시리얼)
//          1            1          C6 (USB_RXD0, USB 시리얼)
//   dip_probe : 1 = UART 핀 확인 모드. 네 핀 모두 입력으로 두고(아무것도 구동하지 않음) LED 로 보여준다.
//     LED1~4 = A3, A5, F6, C6 에서 신호 변화가 있으면 0.2초 켜짐,  LED5~8 = 같은 순서로 현재 레벨
//     PC 가 보내는 동안 켜지는 핀이 PC → FPGA 방향이다. FPGA 는 같은 단자의 다른 핀으로 보내야 한다.
//   dip_ext_off : 1 = 확장 기능 끔 (피에조 무음, 7-세그먼트 꺼짐, LCD 는 평소 문구만, 우주 어둠 없음)
//   dip_cal     : 1 = CDS 보정 표시. 8자리 7-세그먼트에 [ADC 채널] . . [밝기 단계] . [값 3자리]
//                 채널은 1.5초마다 0~7 을 돈다. 우주 스테이지의 어둠은 패킷 상태 바이트 7:6 으로 보낸다
//
// 확장 출력: 1자리 7-세그먼트 = 스테이지 번호, 8자리 7-세그먼트 = 경과 시간(0.01초),
//            텍스트 LCD = 떨어졌을 때 놀림 문구, 피에조 = 차지·점프 효과음
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
    input  wire       dip_uart_sel,
    input  wire       dip_uart_port,
    input  wire       dip_probe,
    input  wire       dip_ext_off,
    input  wire       dip_cal,
    output wire [7:0] led,
    output wire       servo,
    output wire [7:0] seg,           // 1자리 7-세그먼트 {a, b, c, d, e, f, g, dp}
    output wire [7:0] ar_seg,        // 8자리 7-세그먼트 데이터
    output wire [7:0] ar_sel,        // 8자리 7-세그먼트 자리 선택 (0 = 선택)
    output wire       lcd_rs,
    output wire       lcd_rw,
    output wire       lcd_e,
    output wire [7:0] lcd_d,
    output wire       piezo,
    output wire       adc_cs,        // AD7908 (CDS 조도 센서)
    output wire       adc_sclk,
    output wire       adc_din,
    input  wire       adc_dout,
    inout  wire       uart_a3,
    inout  wire       uart_a5,
    inout  wire       uart_f6,
    inout  wire       uart_c6
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
    reg [1:0] trig_s, test_s, sel_s, port_s, probe_s, ext_s, cal_s;
    always @(posedge clk) begin
        trig_s  <= {trig_s[0],  dip_trig     ^ dip_inv};
        test_s  <= {test_s[0],  dip_test     ^ dip_inv};
        sel_s   <= {sel_s[0],   dip_uart_sel ^ dip_inv};
        port_s  <= {port_s[0],  dip_uart_port ^ dip_inv};
        probe_s <= {probe_s[0], dip_probe    ^ dip_inv};
        ext_s   <= {ext_s[0],   dip_ext_off  ^ dip_inv};
        cal_s   <= {cal_s[0],   dip_cal      ^ dip_inv};
    end
    wire trig_mode  = trig_s[1];
    wire test_mode  = test_s[1];
    wire [1:0] uart_idx = {port_s[1], sel_s[1]};      // 0 A3, 1 A5, 2 F6, 3 C6
    wire probe_mode = probe_s[1];
    wire ext_off    = ext_s[1];
    wire cal_mode   = cal_s[1];

    // CDS 조도 센서 (아래 확장 부분에서 연결)
    wire [1:0] dark;
    wire [2:0] cal_ch;
    wire [7:0] cal_val;
    wire [1:0] light_lvl;

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
    wire        facing, land, bounce, fell, rising, send;

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
        .state(state), .facing(facing), .land(land), .bounce(bounce), .fell(fell), .rising(rising), .send(send));

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
    wire [7:0] led_probe;
    wire [7:0] led_mux = probe_mode ? led_probe : led_on;
    assign led = LED_ACTIVE_LOW ? ~led_mux : led_mux;

    servo_pwm #(.PERIOD_US(SERVO_PERIOD_US), .MIN_US(SERVO_MIN_US), .SLOPE(SERVO_SLOPE)) u_servo (
        .clk(clk), .rst(rst), .tick_us(tick_us),
        .angle((SERVO_REVERSE != 0) ? (ANGLE_MAX - angle) : angle), .pwm(servo));

    // ---- 확장: 스테이지 번호 (1자리 7-세그먼트) ----
    wire [6:0] stage_pat;
    seg7_dec u_stage (.digit({1'b0, screen} + 4'd1), .blank(ext_off), .seg(stage_pat));
    assign seg = {stage_pat, 1'b0};

    // ---- 확장: 경과 시간 (8자리 7-세그먼트). 첫 차지부터 세고 클리어에서 멈춘다. 리셋 버튼으로 0 ----
    reg timing;
    always @(posedge clk) begin
        if (rst || rs_rise)      timing <= 1'b0;
        else if (state == 2'd1)  timing <= 1'b1;
    end
    seg_timer #(.CLK_HZ(F_CLK), .S0_IS_LEFT(SEG_S0_IS_LEFT)) u_timer (
        .clk(clk), .rst(rst), .run(timing && state != 2'd3), .clear(rs_rise), .off(ext_off && !cal_mode),
        .cal(cal_mode), .cal_ch(cal_ch), .cal_lvl(light_lvl), .cal_val(cal_val),
        .ar_seg(ar_seg), .ar_sel(ar_sel));

    // ---- 확장: 우주 스테이지 어둠 (CDS 조도 센서) ----
    cds_light #(.TICK_HZ(TICK_HZ), .LIGHT_CH(LIGHT_CH), .LIGHT_INV(LIGHT_INV),
                .T1(LIGHT_T1), .T2(LIGHT_T2), .T3(LIGHT_T3), .HYST(LIGHT_HYST),
                .DARK_SCREEN(DARK_SCREEN)) u_cds (
        .clk(clk), .rst(rst), .tick(tick_game), .screen(screen), .enable(!ext_off),
        .adc_cs(adc_cs), .adc_sclk(adc_sclk), .adc_din(adc_din), .adc_dout(adc_dout),
        .dark(dark), .cal_ch(cal_ch), .cal_val(cal_val), .light_val(), .level(light_lvl));

    // ---- 확장: 텍스트 LCD, 피에조 ----
    lcd_taunt #(.TAUNT_FRAMES(TAUNT_FRAMES)) u_lcd (
        .clk(clk), .rst(rst), .tick_us(tick_us), .tick(tick_game),
        .fell(fell), .screen(screen), .cleared(state == 2'd3), .plain(ext_off),
        .lcd_rs(lcd_rs), .lcd_rw(lcd_rw), .lcd_e(lcd_e), .lcd_d(lcd_d));

    piezo_sfx u_piezo (
        .clk(clk), .rst(rst), .tick_us(tick_us), .tick(tick_game),
        .state(state), .charge(charge), .mute(ext_off), .piezo(piezo));

    // ---- 패킷 송신 ----
    wire [7:0] status = {dark, bounce, land, trig_mode, facing, state};
    wire [7:0] tx_data;
    wire       tx_valid, tx_ready, uart_txd;

    packet_tx u_pkt (
        .clk(clk), .rst(rst),
        .send  (test_mode ? tick_game : send),
        .x_px  (test_mode ? 16'sd320  : {{4{gx[15]}}, gx[15:4]}),
        .y_px  (test_mode ? 16'sd240  : {{4{gy[15]}}, gy[15:4]}),
        .screen(test_mode ? 3'd0      : screen),
        .rising(test_mode ? 1'b0      : rising),
        .charge(test_mode ? 6'd32     : charge),
        .angle (test_mode ? 8'd45     : angle),
        .status(test_mode ? 8'h01     : status),
        .tx_data(tx_data), .tx_valid(tx_valid), .tx_ready(tx_ready), .busy());

    uart_tx #(.CLK_HZ(F_CLK), .BAUD(BAUD)) u_uart (
        .clk(clk), .rst(rst), .data(tx_data), .valid(tx_valid), .ready(tx_ready), .tx(uart_txd));

    // ---- UART 핀: 고른 핀만 구동하고 나머지는 입력 (확인 모드에서는 모두 입력) ----
    wire [3:0] drive = probe_mode ? 4'b0000 : (4'b0001 << uart_idx);
    assign uart_a3 = drive[0] ? uart_txd : 1'bz;
    assign uart_a5 = drive[1] ? uart_txd : 1'bz;
    assign uart_f6 = drive[2] ? uart_txd : 1'bz;
    assign uart_c6 = drive[3] ? uart_txd : 1'bz;

    // 확인 모드: 각 핀의 레벨과 변화 여부를 LED 로
    localparam integer HOLD = F_CLK / 5;               // 0.2초
    wire [3:0] pin_in = {uart_c6, uart_f6, uart_a5, uart_a3};
    reg  [3:0] pin_s0, pin_s1, pin_s2;
    reg  [$clog2(HOLD+1)-1:0] hold [0:3];
    reg  [3:0] active;
    integer k;
    always @(posedge clk) begin
        pin_s0 <= pin_in;
        pin_s1 <= pin_s0;
        pin_s2 <= pin_s1;
        for (k = 0; k < 4; k = k + 1) begin
            if (rst)                         hold[k] <= 0;
            else if (pin_s2[k] != pin_s1[k]) hold[k] <= HOLD;
            else if (hold[k] != 0)           hold[k] <= hold[k] - 1'b1;
            active[k] <= (hold[k] != 0);
        end
    end
    assign led_probe = {pin_s1, active};
endmodule
