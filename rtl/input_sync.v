// input_sync.v — 버튼 하나의 동기화(2단 FF), 접점 떨림 제거(10ms 카운터), 에지 검출.
// in 은 "눌렀을 때 1" 로 맞춰서 넣는다 (극성은 top.v 에서 처리).
module input_sync #(
    parameter integer CLK_HZ      = 50_000_000,
    parameter integer DEBOUNCE_MS = 10
)(
    input  wire clk,
    input  wire rst,
    input  wire in,
    output reg  level,   // 확정된 눌림 상태
    output reg  rise,    // 눌린 순간 1클록
    output reg  fall     // 뗀 순간 1클록
);
    localparam integer CNT_MAX = (CLK_HZ / 1000) * DEBOUNCE_MS;

    reg s0, s1;
    reg [$clog2(CNT_MAX+1)-1:0] cnt;

    always @(posedge clk) begin
        s0   <= in;
        s1   <= s0;
        rise <= 1'b0;
        fall <= 1'b0;
        if (rst) begin
            level <= 1'b0;
            cnt   <= 0;
        end else if (s1 == level) begin
            cnt <= 0;                       // 값이 흔들리면 처음부터 다시 센다
        end else if (cnt == CNT_MAX - 1) begin
            level <= s1;
            rise  <= s1;
            fall  <= ~s1;
            cnt   <= 0;
        end else begin
            cnt <= cnt + 1'b1;
        end
    end
endmodule
