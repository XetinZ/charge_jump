// trig_taylor.v — 삼각함수 테일러 급수 버전 (trig_rom 과 포트가 같다).
// 0~45도만 직접 계산하고 나머지는 대칭으로 접는다. 내부는 소수 16비트, 곱셈기 1개를 8번 쓴다.
//   sin x = x(1 - x²/6 (1 - x²/20)),   cos x = 1 - x²/2 (1 - x²/12)
module trig_taylor (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [7:0]  angle,            // 0 ~ 180
    output reg  signed [13:0] sin,
    output reg  signed [13:0] cos,
    output reg         done
);
    localparam [16:0] ONE     = 17'd65536;
    localparam [16:0] DEG2RAD = 17'd1144;    // pi/180  * 65536
    localparam [16:0] INV6    = 17'd10923;   // 1/6     * 65536
    localparam [16:0] INV12   = 17'd5461;    // 1/12    * 65536
    localparam [16:0] INV20   = 17'd3277;    // 1/20    * 65536

    // 접기: 90도 초과 → 180-angle (cos 부호 반전), 45도 초과 → 90-a (sin/cos 맞바꿈)
    wire [7:0] a = (angle > 8'd90) ? (8'd180 - angle) : angle;
    wire [7:0] b = (a > 8'd45) ? (8'd90 - a) : a;

    // 공유 곱셈기 (부호 없음 17x17)
    reg  [16:0] ma, mb;
    wire [33:0] prod  = ma * mb;
    wire [17:0] pr16  = (prod + 34'd32768) >> 16;   // 반올림해서 소수 16비트로
    wire [16:0] pr17  = (prod + 34'd65536) >> 17;   // 반올림 + 1/2

    reg [3:0]  st;
    reg        neg, swap;
    reg [16:0] xr, x2, sin_t, cos_t;

    // 소수 16비트 → 12비트 (반올림)
    wire [12:0] s12 = ((swap ? cos_t : sin_t) + 17'd8) >> 4;
    wire [12:0] c12 = ((swap ? sin_t : cos_t) + 17'd8) >> 4;

    always @(posedge clk) begin
        done <= 1'b0;
        if (rst) begin
            st  <= 0;
            sin <= 0;
            cos <= 0;
        end else case (st)
            4'd0: if (start) begin
                neg  <= (angle > 8'd90);
                swap <= (a > 8'd45);
                ma <= {9'b0, b}; mb <= DEG2RAD;                   // (1) x = b * pi/180
                st <= 4'd1;
            end
            4'd1: begin xr <= prod[16:0];
                        ma <= prod[16:0]; mb <= prod[16:0];       // (2) x²
                        st <= 4'd2; end
            4'd2: begin x2 <= pr16[16:0];
                        ma <= pr16[16:0]; mb <= INV20;            // (3) x²/20
                        st <= 4'd3; end
            4'd3: begin ma <= x2; mb <= ONE - pr16[16:0];         // (4) x²(1 - x²/20)
                        st <= 4'd4; end
            4'd4: begin ma <= pr16[16:0]; mb <= INV6;             // (5) .../6
                        st <= 4'd5; end
            4'd5: begin ma <= xr; mb <= ONE - pr16[16:0];         // (6) x(1 - ...)
                        st <= 4'd6; end
            4'd6: begin sin_t <= pr16[16:0];
                        ma <= x2; mb <= INV12;                    // (7) x²/12
                        st <= 4'd7; end
            4'd7: begin ma <= x2; mb <= ONE - pr16[16:0];         // (8) x²(1 - x²/12)
                        st <= 4'd8; end
            4'd8: begin cos_t <= ONE - pr17;                      //     1 - .../2
                        st <= 4'd9; end
            4'd9: begin
                sin  <= {1'b0, s12};
                cos  <= neg ? -$signed({1'b0, c12}) : $signed({1'b0, c12});
                done <= 1'b1;
                st   <= 4'd0;
            end
            default: st <= 4'd0;
        endcase
    end
endmodule
