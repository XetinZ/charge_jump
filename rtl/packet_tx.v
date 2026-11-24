// packet_tx.v — 상태를 11바이트 패킷으로 직렬화한다 (명세 4장).
// send 펄스가 온 순간의 값을 복사해 두고 보내므로 전송 중에 값이 바뀌어도 섞이지 않는다.
//   0:0xAA 1:0x55 2-3:x 4-5:y 6:screen 7:charge 8:angle 9:status 10:XOR(2..9)
module packet_tx (
    input  wire        clk,
    input  wire        rst,
    input  wire        send,
    input  wire signed [15:0] x_px,      // 픽셀 정수부
    input  wire signed [15:0] y_px,
    input  wire [2:0]  screen,
    input  wire [5:0]  charge,
    input  wire [7:0]  angle,
    input  wire [7:0]  status,
    output reg  [7:0]  tx_data,
    output reg         tx_valid,
    input  wire        tx_ready,
    output reg         busy
);
    reg [63:0] payload;     // 바이트 2~9, 상위 바이트 먼저
    reg [3:0]  idx;
    reg [7:0]  csum;

    wire [7:0] cur = (idx == 4'd0)  ? 8'hAA :
                     (idx == 4'd1)  ? 8'h55 :
                     (idx == 4'd10) ? csum  : payload[63:56];

    always @(posedge clk) begin
        if (rst) begin
            busy     <= 1'b0;
            tx_valid <= 1'b0;
            idx      <= 0;
            csum     <= 0;
        end else if (!busy) begin
            tx_valid <= 1'b0;
            if (send) begin
                payload <= {x_px, y_px, 5'b0, screen, 2'b0, charge, angle, status};
                idx     <= 0;
                csum    <= 0;
                busy    <= 1'b1;
            end
        end else if (tx_valid) begin
            // 이번 클록에 uart_tx 가 바이트를 가져갔다
            tx_valid <= 1'b0;
            if (idx >= 4'd2 && idx <= 4'd9) begin
                csum    <= csum ^ cur;
                payload <= {payload[55:0], 8'h00};
            end
            if (idx == 4'd10) busy <= 1'b0;
            else              idx  <= idx + 1'b1;
        end else if (tx_ready) begin
            tx_data  <= cur;
            tx_valid <= 1'b1;
        end
    end
endmodule
