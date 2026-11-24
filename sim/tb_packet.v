`timescale 1ns/1ps
// tb_packet — packet_tx + uart_tx. 직렬 출력을 다시 받아 11바이트 내용과 체크섬을 확인한다.
// 전송 도중 입력 값을 바꿔도 패킷이 섞이지 않는지도 본다.
module tb_packet;
    localparam integer CLK_HZ = 1_152_000, BAUD = 115200;   // 분주비 10
    localparam integer DIV = 10;
    reg clk = 0, rst = 1, send = 0;
    always #5 clk = ~clk;

    reg signed [15:0] x_px = 0, y_px = 0;
    reg [2:0] screen = 0;
    reg [5:0] charge = 0;
    reg [7:0] angle = 0, status = 0;
    wire [7:0] tx_data;
    wire tx_valid, tx_ready, txd, busy;

    packet_tx u_pkt (.clk(clk), .rst(rst), .send(send), .x_px(x_px), .y_px(y_px), .screen(screen),
                     .charge(charge), .angle(angle), .status(status),
                     .tx_data(tx_data), .tx_valid(tx_valid), .tx_ready(tx_ready), .busy(busy));
    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_uart (.clk(clk), .rst(rst), .data(tx_data),
                     .valid(tx_valid), .ready(tx_ready), .tx(txd));

    // ---- 수신기 (비트 중앙에서 표본) ----
    reg [7:0] rx [0:63];
    integer nrx = 0, errors = 0, i;
    reg [7:0] sh;
    always begin
        @(negedge txd);
        repeat (DIV + DIV / 2) @(posedge clk);
        for (i = 0; i < 8; i = i + 1) begin sh[i] = txd; repeat (DIV) @(posedge clk); end
        if (txd !== 1'b1) begin errors = errors + 1; $display("  FAIL stop bit"); end
        rx[nrx] = sh; nrx = nrx + 1;
    end

    task check_packet;
        input integer base;
        input signed [15:0] ex, ey;
        input [7:0] es, ec, ea, est;
        reg [7:0] cs;
        integer k;
        begin
            cs = 0;
            for (k = 2; k <= 9; k = k + 1) cs = cs ^ rx[base + k];
            if (rx[base] !== 8'hAA || rx[base+1] !== 8'h55 ||
                {rx[base+2], rx[base+3]} !== ex || {rx[base+4], rx[base+5]} !== ey ||
                rx[base+6] !== es || rx[base+7] !== ec || rx[base+8] !== ea || rx[base+9] !== est ||
                rx[base+10] !== cs) begin
                errors = errors + 1;
                $display("  FAIL packet %0d content mismatch", base / 11);
            end
        end
    endtask

    initial begin
        repeat (4) @(negedge clk); rst = 0;
        // 패킷 1
        x_px = 16'sd320; y_px = 16'sd240; screen = 3'd2; charge = 6'd63; angle = 8'd180; status = 8'h35;
        @(negedge clk) send = 1; @(negedge clk) send = 0;
        // 전송 중 값 변경 + 전송 중 send 는 무시되어야 한다
        repeat (300) @(negedge clk);
        x_px = -16'sd5; y_px = -16'sd20; screen = 3'd7; charge = 6'd1; angle = 8'd0; status = 8'h0A;
        @(negedge clk) send = 1; @(negedge clk) send = 0;
        wait (!busy); repeat (2 * DIV) @(negedge clk);
        // 패킷 2 (음수 좌표)
        @(negedge clk) send = 1; @(negedge clk) send = 0;
        wait (busy); wait (!busy); repeat (12 * DIV) @(negedge clk);

        if (nrx !== 22) begin errors = errors + 1; $display("  FAIL byte count %0d (want 22)", nrx); end
        check_packet(0,  16'sd320, 16'sd240, 8'd2, 8'd63, 8'd180, 8'h35);
        check_packet(11, -16'sd5, -16'sd20,  8'd7, 8'd1,  8'd0,   8'h0A);
        if (errors == 0) $display("PASS (%0d bytes)", nrx); else $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule
