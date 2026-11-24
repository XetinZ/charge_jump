// tick_gen.v — 클록에서 60Hz 게임 틱과 1MHz 틱(서보용)을 만든다. 둘 다 1클록 펄스.
// CLK_HZ 는 1MHz 이상이어야 한다. 1MHz 이면 tick_us 는 매 클록 1 이다.
module tick_gen #(
    parameter integer CLK_HZ  = 50_000_000,
    parameter integer TICK_HZ = 60
)(
    input  wire clk,
    input  wire rst,
    output reg  tick_game,
    output reg  tick_us
);
    localparam integer GAME_DIV = CLK_HZ / TICK_HZ;
    localparam integer US_DIV   = CLK_HZ / 1_000_000;

    reg [$clog2(GAME_DIV)-1:0] game_cnt;
    reg [$clog2(US_DIV+1)-1:0] us_cnt;

    always @(posedge clk) begin
        tick_game <= 1'b0;
        tick_us   <= 1'b0;
        if (rst) begin
            game_cnt <= 0;
            us_cnt   <= 0;
        end else begin
            if (game_cnt == GAME_DIV - 1) begin
                game_cnt  <= 0;
                tick_game <= 1'b1;
            end else
                game_cnt <= game_cnt + 1'b1;

            if (us_cnt == US_DIV - 1) begin
                us_cnt  <= 0;
                tick_us <= 1'b1;
            end else
                us_cnt <= us_cnt + 1'b1;
        end
    end
endmodule
