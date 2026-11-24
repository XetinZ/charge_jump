// servo_pwm.v — 각도(0~180)를 50Hz 서보 PWM 으로 바꾼다.
// 펄스 폭[us] = MIN_US + (angle * SLOPE) >> 8  →  0도 0.7ms, 90도 1.5ms, 180도 2.3ms (params.vh 값)
module servo_pwm #(
    parameter integer PERIOD_US = 20000,
    parameter integer MIN_US    = 700,
    parameter integer SLOPE     = 2276
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       tick_us,    // 1MHz
    input  wire [7:0] angle,
    output reg        pwm
);
    reg  [14:0] cnt;
    reg  [11:0] width;
    wire [18:0] scaled = angle * SLOPE;
    wire [11:0] width_next = MIN_US + scaled[18:8];

    always @(posedge clk) begin
        if (rst) begin
            cnt   <= 0;
            width <= MIN_US + ((90 * SLOPE) >> 8);
            pwm   <= 1'b0;
        end else begin
            if (tick_us) begin
                if (cnt == PERIOD_US - 1) begin
                    cnt   <= 0;
                    width <= width_next;      // 주기 시작에서만 폭을 바꾼다
                end else
                    cnt <= cnt + 1'b1;
            end
            pwm <= (cnt < {3'b0, width});
        end
    end
endmodule
