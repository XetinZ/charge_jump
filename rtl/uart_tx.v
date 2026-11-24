// uart_tx.v — 8N1 송신기. valid && ready 인 클록에 data 를 받아 보낸다.
module uart_tx #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer BAUD   = 115200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] data,
    input  wire       valid,
    output wire       ready,
    output wire       tx
);
    localparam integer DIV = (CLK_HZ + BAUD / 2) / BAUD;   // 반올림

    reg [9:0] sh;                    // {정지, 데이터 8비트, 시작}, LSB 먼저
    reg [3:0] nbit;                  // 남은 비트 수
    reg [$clog2(DIV)-1:0] cnt;

    assign ready = (nbit == 0);
    assign tx    = sh[0];

    always @(posedge clk) begin
        if (rst) begin
            sh   <= 10'h3FF;
            nbit <= 0;
            cnt  <= 0;
        end else if (ready) begin
            if (valid) begin
                sh   <= {1'b1, data, 1'b0};
                nbit <= 4'd10;
                cnt  <= 0;
            end
        end else if (cnt == DIV - 1) begin
            cnt  <= 0;
            sh   <= {1'b1, sh[9:1]};
            nbit <= nbit - 1'b1;
        end else begin
            cnt <= cnt + 1'b1;
        end
    end
endmodule
