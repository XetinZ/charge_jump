// cds_light.v — CDS 조도 센서로 우주 스테이지의 어둠 단계를 정한다.
//   보드의 ADC 는 AD7908 (8채널 8비트, SPI). 8채널을 차례로 계속 읽는다.
//   AD7908 규칙 (데이터시트):
//     - CS 를 내리면 한 프레임(SCLK 16개). DIN 은 SCLK 하강 에지에서 칩이 읽고,
//       DOUT 은 하강 에지마다 바뀐다. 첫 비트(0)는 CS 를 내릴 때 나온다.
//     - DOUT 프레임: 0, 채널 주소 3비트, 데이터 8비트, 0 네 개. 주소는 그 결과의 채널
//     - DIN 앞 12비트 = 제어 레지스터: WRITE SEQ x ADD2 ADD1 ADD0 PM1 PM0 SHADOW x RANGE CODING
//     - 전원 인가 후 DIN 을 모두 1 로 한 프레임 2개를 먼저 보낸다
//   여기서는 SCLK 를 클록의 1/4 로 돌리고, 하강 에지 직전에 DOUT 을 읽고 상승 에지 직후에 DIN 을 바꾼다.
//
//   dark: 0 = 어둡게 하지 않음, 1~3 = 점점 어둡게 (화면 DARK_SCREEN 에서, enable 일 때만)
module cds_light #(
    parameter integer TICK_HZ     = 60,
    parameter integer LIGHT_CH    = 0,      // CDS 가 연결된 ADC 채널
    parameter integer LIGHT_INV   = 0,      // 1 = 밝을수록 값이 작아지는 회로
    parameter integer T1          = 64,     // 이 값 이상이면 어둠 2
    parameter integer T2          = 128,    // 이 값 이상이면 어둠 1
    parameter integer T3          = 192,    // 이 값 이상이면 어둠 0 (밝음)
    parameter integer HYST        = 6,      // 단계가 오락가락하지 않게 두는 여유
    parameter integer DARK_SCREEN = 2
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       tick,                 // 60Hz
    input  wire [2:0] screen,
    input  wire       enable,
    output reg        adc_cs,
    output reg        adc_sclk,
    output reg        adc_din,
    input  wire       adc_dout,
    output reg  [1:0] dark,
    // 보정 표시용: 채널을 1.5초마다 바꿔 가며 그 채널의 값을 보여준다
    output reg  [2:0] cal_ch,
    output wire [7:0] cal_val,
    output wire [7:0] light_val,            // LIGHT_CH 의 값 (LIGHT_INV 적용 전)
    output wire [1:0] level                 // 지금 밝기 단계 0~3 (3 = 밝음)
);
    // ---------------- SPI 프레임 ----------------
    reg  [7:0]  val [0:7];
    reg  [1:0]  ph;                         // SCLK 1주기 = 4클록
    reg  [4:0]  bitn;                       // 보낼/받을 비트 (15..0), 16 = 프레임 사이
    reg  [15:0] tx, rx;
    reg  [1:0]  dummy;                      // 남은 전원 인가 프레임 수
    reg  [2:0]  next_ch;
    reg  [2:0]  gap;
    reg         first;                      // 전원 인가 프레임 뒤 첫 정상 프레임의 결과는 버린다
    integer     k;

    wire [15:0] ctrl = {1'b1, 1'b0, 1'b0, next_ch, 2'b11, 1'b0, 1'b0, 1'b1, 1'b1, 4'b0000};
    //                  WRITE SEQ  x     ADD      PM=normal SHADOW x  RANGE=REFIN CODING=binary

    always @(posedge clk) begin
        if (rst) begin
            adc_cs   <= 1'b1;
            adc_sclk <= 1'b1;
            adc_din  <= 1'b1;
            ph       <= 0;
            bitn     <= 5'd16;
            dummy    <= 2'd2;
            next_ch  <= 0;
            gap      <= 0;
            for (k = 0; k < 8; k = k + 1) val[k] <= 8'd0;
        end else if (bitn == 5'd16) begin
            // 프레임 사이: CS 를 올린 채 잠깐 쉬고 다음 프레임 시작
            adc_cs   <= 1'b1;
            adc_sclk <= 1'b1;
            gap      <= gap + 3'd1;
            if (gap == 3'd7) begin
                tx       <= (dummy != 0) ? 16'hFFFF : ctrl;
                adc_cs   <= 1'b0;
                bitn     <= 5'd15;
                ph       <= 0;
            end
        end else begin
            ph <= ph + 2'd1;
            case (ph)
                2'd0: adc_din <= tx[bitn];                      // SCLK 높음: DIN 준비
                2'd1: begin rx[bitn] <= adc_dout;               // 하강 직전: DOUT 읽기
                            adc_sclk <= 1'b0; end               // 하강 에지: 칩이 DIN 을 읽고 DOUT 을 바꿈
                2'd2: ;
                2'd3: begin
                    adc_sclk <= 1'b1;
                    if (bitn == 0) begin                        // 프레임 끝
                        bitn <= 5'd16;
                        gap  <= 0;
                        if (dummy != 0) dummy <= dummy - 2'd1;
                        else begin
                            next_ch <= next_ch + 3'd1;
                            // rx: 0, 주소 3비트, 데이터 8비트, 0000. 첫 정상 프레임의 결과는 버린다
                            if (rx[15] == 1'b0 && rx[3:0] == 4'b0000 && !first)
                                val[rx[14:12]] <= rx[11:4];
                        end
                    end else
                        bitn <= bitn - 5'd1;
                end
            endcase
        end
    end
    always @(posedge clk) begin
        if (rst) first <= 1'b1;
        else if (bitn == 5'd0 && ph == 2'd3 && dummy == 0) first <= 1'b0;
    end

    // ---------------- 밝기 단계 ----------------
    assign light_val = val[LIGHT_CH];
    wire [7:0] v = (LIGHT_INV != 0) ? ~light_val : light_val;

    function [1:0] lvl_of;                  // 3 = 밝음
        input [8:0] x;
        lvl_of = (x >= T3) ? 2'd3 : (x >= T2) ? 2'd2 : (x >= T1) ? 2'd1 : 2'd0;
    endfunction
    wire [1:0] cand    = lvl_of({1'b0, v});
    wire [1:0] cand_lo = lvl_of((v > HYST) ? {1'b0, v} - HYST : 9'd0);
    wire [1:0] cand_hi = lvl_of({1'b0, v} + HYST);

    reg [1:0] lvl;
    assign level = lvl;
    always @(posedge clk) begin
        if (rst) lvl <= 2'd3;
        else if (tick) begin
            if (cand > lvl && cand_lo == cand) lvl <= cand;      // 확실히 밝아졌을 때만 올림
            if (cand < lvl && cand_hi == cand) lvl <= cand;      // 확실히 어두워졌을 때만 내림
        end
    end

    always @(posedge clk) begin
        if (rst) dark <= 2'd0;
        else     dark <= (enable && screen == DARK_SCREEN) ? (2'd3 - lvl) : 2'd0;
    end

    // ---------------- 보정 표시 채널 ----------------
    reg [6:0] cal_cnt;
    always @(posedge clk) begin
        if (rst) begin
            cal_ch  <= 0;
            cal_cnt <= 0;
        end else if (tick) begin
            if (cal_cnt == TICK_HZ * 3 / 2 - 1) begin
                cal_cnt <= 0;
                cal_ch  <= cal_ch + 3'd1;
            end else
                cal_cnt <= cal_cnt + 7'd1;
        end
    end
    assign cal_val = val[cal_ch];
endmodule
