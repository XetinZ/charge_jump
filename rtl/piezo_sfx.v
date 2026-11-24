// piezo_sfx.v — 피에조 효과음.
//   차지 중: 차지 값이 오를수록 높아지는 음 (300Hz → 약 760Hz)
//   점프 순간: 약 0.17초 동안 빠르게 올라가는 음 (약 960Hz → 2.1kHz)
module piezo_sfx (
    input  wire       clk,
    input  wire       rst,
    input  wire       tick_us,       // 1MHz
    input  wire       tick,          // 60Hz
    input  wire [1:0] state,         // 0 대기, 1 차지, 2 공중, 3 클리어
    input  wire [5:0] charge,
    input  wire       mute,
    output reg        piezo
);
    reg [1:0]  state_d;
    reg [3:0]  jump_cnt;             // 점프음 남은 프레임
    reg [10:0] cnt;

    // 반주기 [us]
    wire [10:0] hp_charge = 11'd1666 - {1'b0, charge, 4'b0000};
    wire [10:0] hp_jump   = 11'd200 + {2'b00, jump_cnt, 5'b00000};
    wire        sound     = !mute && (jump_cnt != 0 || state == 2'd1);
    wire [10:0] hp        = (jump_cnt != 0) ? hp_jump : hp_charge;

    always @(posedge clk) begin
        if (rst) begin
            state_d  <= 0;
            jump_cnt <= 0;
            cnt      <= 0;
            piezo    <= 1'b0;
        end else begin
            if (tick) begin
                state_d <= state;
                if (state_d == 2'd1 && state == 2'd2) jump_cnt <= 4'd10;
                else if (jump_cnt != 0)               jump_cnt <= jump_cnt - 4'd1;
            end
            if (!sound) begin
                cnt   <= 0;
                piezo <= 1'b0;
            end else if (tick_us) begin
                if (cnt >= hp - 11'd1) begin
                    cnt   <= 0;
                    piezo <= ~piezo;
                end else
                    cnt <= cnt + 11'd1;
            end
        end
    end
endmodule
