// led_gauge.v — 차지 값을 LED 8개 막대로 표시한다.
// 차지 상태에서 charge[5:3]+1 개를 led[0] 부터 켜고, 63이면 약 4Hz 로 깜빡인다.
module led_gauge (
    input  wire       clk,
    input  wire       rst,
    input  wire       tick,       // 60Hz
    input  wire       charging,
    input  wire [5:0] charge,
    output reg  [7:0] led         // 1 = 켜짐 (극성은 top.v 에서 처리)
);
    reg  [3:0] blink;             // 16틱 주기 = 3.75Hz
    wire [7:0] bar = 8'hFF >> (3'd7 - charge[5:3]);

    always @(posedge clk) begin
        if (rst) begin
            blink <= 0;
            led   <= 8'h00;
        end else begin
            if (tick) blink <= blink + 1'b1;
            if (!charging)                      led <= 8'h00;
            else if (charge == 6'd63 && blink[3]) led <= 8'h00;
            else                                led <= bar;
        end
    end
endmodule
