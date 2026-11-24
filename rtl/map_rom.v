// map_rom.v — 타일 맵 ROM (블록 RAM, 동기 읽기 1클록).
// addr = {screen[2:0], ty[4:0], tx[5:0]},  data: 0 빈칸, 1 막힘, 2 목표, 3 예약
module map_rom #(
    parameter MEM_FILE = "map.mem"
)(
    input  wire        clk,
    input  wire [13:0] addr,
    output reg  [1:0]  data
);
    (* rom_style = "block" *) reg [1:0] mem [0:16383];
    initial $readmemh(MEM_FILE, mem);

    always @(posedge clk)
        data <= mem[addr];
endmodule
