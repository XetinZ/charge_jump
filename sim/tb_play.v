`timescale 1ns/1ps
// tb_play — 실제 맵(map.mem)을 정해진 점프 순서로 시작부터 클리어까지 3회 연속 플레이한다.
// 맵이나 물리 상수를 바꾸면 아래 경로(차지, 각도)를 다시 잡아야 한다.
module tb_play;
    localparam MAP_FILE = "map.mem";
    localparam integer T_NSCR = -1, T_SX = -1, T_SY = -1;     // params.vh 값 사용
    `include "tb_harness.vh"

    localparam integer NJ = 19;
    reg [7:0] r_ch [0:NJ-1];
    reg [7:0] r_an [0:NJ-1];
    integer run, j, n;

    initial begin
        r_ch[ 0]=59; r_an[ 0]= 75;   r_ch[ 1]=59; r_an[ 1]= 65;   r_ch[ 2]=55; r_an[ 2]= 60;
        r_ch[ 3]=51; r_an[ 3]=125;   r_ch[ 4]=63; r_an[ 4]=135;   r_ch[ 5]=59; r_an[ 5]= 80;
        r_ch[ 6]=63; r_an[ 6]= 45;   r_ch[ 7]=55; r_an[ 7]=115;   r_ch[ 8]=59; r_an[ 8]=115;
        r_ch[ 9]=47; r_an[ 9]= 65;   r_ch[10]=55; r_an[10]= 60;   r_ch[11]=63; r_an[11]= 70;
        r_ch[12]=59; r_an[12]=110;   r_ch[13]=55; r_an[13]=125;   r_ch[14]=51; r_an[14]= 60;
        r_ch[15]=55; r_an[15]= 65;   r_ch[16]=63; r_an[16]=110;   r_ch[17]=63; r_an[17]=115;
        r_ch[18]=39; r_an[18]=130;

        repeat (4) @(negedge clk); rst = 0;
        do_tick;
        for (run = 1; run <= 3; run = run + 1) begin
            expect_eq("start: idle", state, 0);
            expect_eq("start: screen 0", screen, 0);
            for (j = 0; j < NJ; j = j + 1) begin
                start_jump(r_ch[j], r_an[j]);
                fly(n);
                $display("  run %0d jump %0d: charge %0d angle %0d -> screen %0d (%0d, %0d) state %0d",
                         run, j + 1, r_ch[j], r_an[j], screen, px, py, state);
            end
            expect_eq("clear", state, 3);
            expect_eq("clear: screen", screen, 2);
            repeat (20) do_tick;
            expect_eq("clear persists", state, 3);
            pulse_reset;
        end
        finish_tb;
    end
endmodule
