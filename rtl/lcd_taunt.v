// lcd_taunt.v — 16x2 텍스트 LCD (HD44780, 8비트 모드).
//   평소:              "  CHARGE  JUMP  " / "    STAGE n     "
//   아래로 떨어진 직후: "☻ m9(^▽^) LOL! ☻" / " FELL TO STAGE n"   (TAUNT_FRAMES 동안)
//   클리어:            "**** CLEAR! ****" / "   GOOD JOB! ☻  "
// 웃는 얼굴(☻)과 벌린 입(▽)은 CGRAM 사용자 문자 1, 2 로 만든다.
// 초기화 뒤에는 두 줄을 계속 다시 쓴다 (한 번에 약 70ms).
module lcd_taunt #(
    parameter integer TAUNT_FRAMES = 180
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       tick_us,       // 1MHz
    input  wire       tick,          // 60Hz
    input  wire       fell,          // 아래 화면으로 떨어진 프레임에 1
    input  wire [2:0] screen,
    input  wire       cleared,
    input  wire       plain,         // 1 = 평소 문구만 (확장 기능 끔)
    output reg        lcd_rs,
    output wire       lcd_rw,
    output reg        lcd_e,
    output reg  [7:0] lcd_d
);
    assign lcd_rw = 1'b0;            // 쓰기만 한다

    // ---- 문구 (16자). '#' = 웃는 얼굴, '$' = 벌린 입, '@' = 스테이지 번호 ----
    localparam [127:0] N1 = "  CHARGE  JUMP  ";
    localparam [127:0] N2 = "    STAGE @     ";
    localparam [127:0] T1 = "# m9(^$^) LOL! #";
    localparam [127:0] T2 = " FELL TO STAGE @";
    localparam [127:0] C1 = "**** CLEAR! ****";
    localparam [127:0] C2 = "   GOOD JOB! #  ";

    // ---- 놀림 문구 타이머 ----
    reg [8:0] taunt_cnt;
    always @(posedge clk) begin
        if (rst)             taunt_cnt <= 0;
        else if (fell)       taunt_cnt <= TAUNT_FRAMES;
        else if (tick && taunt_cnt != 0) taunt_cnt <= taunt_cnt - 9'd1;
    end
    wire [1:0] mode_now = plain ? 2'd0 : (taunt_cnt != 0) ? 2'd1 : cleared ? 2'd2 : 2'd0;

    // ---- 사용자 문자 (5x8) ----
    function [7:0] cgram;
        input [3:0] i;
        case (i)
            // 문자 1: 웃는 얼굴
            4'd0:  cgram = 8'b00000;
            4'd1:  cgram = 8'b01010;
            4'd2:  cgram = 8'b01010;
            4'd3:  cgram = 8'b00000;
            4'd4:  cgram = 8'b11111;
            4'd5:  cgram = 8'b10001;
            4'd6:  cgram = 8'b01110;
            4'd7:  cgram = 8'b00000;
            // 문자 2: 크게 벌린 입
            4'd8:  cgram = 8'b00000;
            4'd9:  cgram = 8'b11111;
            4'd10: cgram = 8'b10001;
            4'd11: cgram = 8'b10001;
            4'd12: cgram = 8'b01010;
            4'd13: cgram = 8'b00100;
            4'd14: cgram = 8'b00000;
            default: cgram = 8'b00000;
        endcase
    endfunction

    // ---- 보낼 순서: 초기화 6 + CGRAM 17 + (줄 주소 1 + 16자) x 2 ----
    localparam [5:0] S_CGRAM = 6'd6, S_LOOP = 6'd23, S_END = 6'd57;
    reg [5:0] step;
    reg [1:0] mode;                  // 한 번 쓰는 동안은 문구를 바꾸지 않는다
    reg [2:0] scr;

    wire [5:0]   li   = step - S_LOOP;                       // 0..33
    wire         l2   = (li >= 6'd17);
    wire [3:0]   col  = l2 ? (li - 6'd18) : (li - 6'd1);
    wire [127:0] line = (mode == 2'd1) ? (l2 ? T2 : T1) :
                        (mode == 2'd2) ? (l2 ? C2 : C1) : (l2 ? N2 : N1);
    wire [7:0]   raw  = line[8 * (15 - col) +: 8];
    wire [7:0]   ch   = (raw == "#") ? 8'h01 :
                        (raw == "$") ? 8'h02 :
                        (raw == "@") ? (8'h31 + {5'b0, scr}) : raw;

    reg       cur_rs;
    reg [7:0] cur_d;
    always @(*) begin
        cur_rs = 1'b0;
        case (step)
            6'd0, 6'd1, 6'd2: cur_d = 8'h38;                 // 8비트, 2줄, 5x8
            6'd3:             cur_d = 8'h0C;                 // 표시 켬, 커서 끔
            6'd4:             cur_d = 8'h01;                 // 지우기
            6'd5:             cur_d = 8'h06;                 // 오른쪽으로 진행
            6'd6:             cur_d = 8'h48;                 // CGRAM 문자 1 의 주소
            default: begin
                if (step < S_LOOP) begin
                    cur_rs = 1'b1;
                    cur_d  = cgram(step - 6'd7);
                end else if (li == 6'd0)  cur_d = 8'h80;     // 첫째 줄 처음
                else if (li == 6'd17)     cur_d = 8'hC0;     // 둘째 줄 처음
                else begin
                    cur_rs = 1'b1;
                    cur_d  = ch;
                end
            end
        endcase
    end

    // ---- 한 번 쓰기: RS·데이터 준비 → E 를 2us 올림 → 대기 ----
    localparam [15:0] T_POWER = 16'd50000,       // 전원 인가 후 50ms
                      T_INIT  = 16'd5000,        // 초기화 명령 사이 5ms
                      T_OP    = 16'd2000;        // 그 밖의 명령·문자 2ms
    reg [15:0] wait_cnt;
    reg [1:0]  ph;                               // 0 대기, 1 준비, 2 E 올림, 3 E 내림

    always @(posedge clk) begin
        if (rst) begin
            step     <= 0;
            mode     <= 0;
            scr      <= 0;
            ph       <= 0;
            wait_cnt <= T_POWER;
            lcd_e    <= 1'b0;
            lcd_rs   <= 1'b0;
            lcd_d    <= 8'h00;
        end else if (tick_us) begin
            case (ph)
                2'd0: if (wait_cnt != 0) wait_cnt <= wait_cnt - 16'd1;
                      else begin
                          lcd_rs <= cur_rs;
                          lcd_d  <= cur_d;
                          ph     <= 2'd1;
                      end
                2'd1: begin lcd_e <= 1'b1; ph <= 2'd2; end
                2'd2: ph <= 2'd3;
                2'd3: begin
                    lcd_e    <= 1'b0;
                    wait_cnt <= (step < S_CGRAM) ? T_INIT : T_OP;
                    ph       <= 2'd0;
                    if (step == S_END - 1) begin             // 두 줄을 다 썼다 → 문구를 다시 고르고 처음부터
                        step <= S_LOOP;
                        mode <= mode_now;
                        scr  <= screen;
                    end else begin
                        step <= step + 6'd1;
                        if (step == S_LOOP - 1) begin
                            mode <= mode_now;
                            scr  <= screen;
                        end
                    end
                end
            endcase
        end
    end
endmodule
