// trig_rom.v — 삼각함수 ROM 표 버전. 0~90도의 sin 91개(소수 12비트)를 두고
// cos 는 sin(90-a) 로 읽는다. start 후 3클록 뒤 done.
module trig_rom #(
    parameter MEM_FILE = "sin.mem"
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [7:0]  angle,            // 0 ~ 180
    output reg  signed [13:0] sin,
    output reg  signed [13:0] cos,
    output reg         done
);
    (* rom_style = "block" *) reg [12:0] tab [0:90];
    initial $readmemh(MEM_FILE, tab);

    reg  [6:0]  addr;
    reg  [12:0] q;
    always @(posedge clk) q <= tab[addr];

    wire [7:0] a_fold = (angle > 8'd90) ? (8'd180 - angle) : angle;

    reg [1:0] st;
    reg [6:0] a;
    reg       neg;

    always @(posedge clk) begin
        done <= 1'b0;
        if (rst) begin
            st   <= 0;
            sin  <= 0;
            cos  <= 0;
            addr <= 0;
        end else case (st)
            2'd0: if (start) begin
                a    <= a_fold[6:0];
                neg  <= (angle > 8'd90);
                addr <= a_fold[6:0];
                st   <= 2'd1;
            end
            2'd1: begin addr <= 7'd90 - a; st <= 2'd2; end
            2'd2: begin sin <= {1'b0, q};  st <= 2'd3; end
            2'd3: begin
                cos  <= neg ? -$signed({1'b0, q}) : $signed({1'b0, q});
                done <= 1'b1;
                st   <= 2'd0;
            end
        endcase
    end
endmodule
