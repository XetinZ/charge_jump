// seg_timer.v — 8자리 7-세그먼트에 경과 시간을 0.01초 단위로 표시한다 (예: "   12.34").
// run 이 1인 동안 센다. clear 로 0. 자리는 스캔 방식: 선택한 자리의 common(ar_sel)만 0.
module seg_timer #(
    parameter integer CLK_HZ     = 1_000_000,
    parameter integer S0_IS_LEFT = 1          // AR_SEG_S0 이 맨 왼쪽 자리면 1
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       run,
    input  wire       clear,
    input  wire       off,                    // 1 = 표시 끔
    // 보정 표시 (cal = 1): 맨 왼쪽 = ADC 채널, 왼쪽 4번째 = 밝기 단계, 오른쪽 3자리 = 값
    input  wire       cal,
    input  wire [2:0] cal_ch,
    input  wire [1:0] cal_lvl,
    input  wire [7:0] cal_val,
    output reg  [7:0] ar_seg,                 // {a, b, c, d, e, f, g, dp}, 1 = 켜짐
    output reg  [7:0] ar_sel                  // 자리 선택, 0 = 선택
);
    localparam integer CS_DIV   = CLK_HZ / 100;      // 0.01초
    localparam integer SCAN_DIV = CLK_HZ / 1000;     // 자리당 1ms → 전체 125Hz

    // d[0] = 0.01초 자리 ... d[7] = 10만 초 자리 (BCD)
    reg [3:0] d [0:7];
    reg [$clog2(CS_DIV)-1:0]   cs_cnt;
    reg [$clog2(SCAN_DIV)-1:0] scan_cnt;
    reg [2:0] idx;                                   // 지금 켜는 자리 (0 = 맨 오른쪽)
    integer   k;

    // 자리 k 는 아래 자리가 모두 9 일 때 올라간다
    reg [7:0] nine, inc_en;
    always @(*) begin
        for (k = 0; k < 8; k = k + 1) nine[k] = (d[k] == 4'd9);
        inc_en[0] = 1'b1;
        for (k = 1; k < 8; k = k + 1) inc_en[k] = inc_en[k-1] & nine[k-1];
    end
    wire full = &nine;

    always @(posedge clk) begin
        if (rst || clear) begin
            cs_cnt <= 0;
            for (k = 0; k < 8; k = k + 1) d[k] <= 4'd0;
        end else if (run && !full) begin
            if (cs_cnt == CS_DIV - 1) begin
                cs_cnt <= 0;
                for (k = 0; k < 8; k = k + 1)
                    if (inc_en[k]) d[k] <= nine[k] ? 4'd0 : d[k] + 4'd1;
            end else
                cs_cnt <= cs_cnt + 1'b1;
        end
    end

    // 앞자리 0 은 끈다. 1초 자리(d[2])부터 아래는 항상 표시
    reg blank;
    always @(*) begin
        blank = (idx > 3'd2);
        for (k = 3; k < 8; k = k + 1)
            if (k >= idx && d[k] != 4'd0) blank = 1'b0;
    end

    // 보정 표시 내용
    wire [3:0] v100 = cal_val / 8'd100;
    wire [3:0] v10  = (cal_val / 8'd10) % 8'd10;
    wire [3:0] v1   = cal_val % 8'd10;
    reg  [3:0] cdig;
    reg        cblank;
    always @(*) begin
        cblank = 1'b0;
        case (idx)
            3'd7: cdig = {1'b0, cal_ch};
            3'd4: cdig = {2'b00, cal_lvl};
            3'd2: begin cdig = v100; cblank = (v100 == 0); end
            3'd1: begin cdig = v10;  cblank = (v100 == 0 && v10 == 0); end
            3'd0: cdig = v1;
            default: begin cdig = 4'd0; cblank = 1'b1; end
        endcase
    end

    wire [6:0] pat;
    seg7_dec u_dec (.digit(cal ? cdig : d[idx]), .blank(cal ? cblank : blank), .seg(pat));
    wire [2:0] sel_bit = (S0_IS_LEFT != 0) ? (3'd7 - idx) : idx;

    always @(posedge clk) begin
        if (rst) begin
            scan_cnt <= 0;
            idx      <= 0;
            ar_seg   <= 8'h00;
            ar_sel   <= 8'hFF;
        end else begin
            if (scan_cnt == SCAN_DIV - 1) begin
                scan_cnt <= 0;
                idx      <= idx + 3'd1;
            end else
                scan_cnt <= scan_cnt + 1'b1;
            ar_seg <= off ? 8'h00 : {pat, (idx == 3'd2) && !cal};   // 소수점은 1초 자리 뒤
            ar_sel <= off ? 8'hFF : ~(8'h01 << sel_bit);
        end
    end
endmodule
