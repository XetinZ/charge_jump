`timescale 1ns/1ps
// tb_physics — 차지, 각도 버튼, 평지 점프 궤적 (명세 8장 "차지", "각도", "물리").
// 프레임별 좌표를 physics_trace.txt 로 출력한다.
//
// 손 계산 (소수 4비트 원시값, 시작 py = 448, ROM 표 사용):
//  [수직, 차지 63]  speed = 64 + 63*2 = 190, sin90 = 4096 → vy0 = -190
//     k번째 프레임의 vy = -190 + 8k, 누적 이동 = 4k^2 - 186k
//     최고점: k = 23 에서 -2162 (= -135.125px) → py = 448 - 136 = 312
//     착지:   k = 46 에서 -92 (아직 위), k = 47 에서 +94 → 47번째 프레임에 착지, py = 448
//  [45도, 차지 63]  cos45 = sin45 = 2896 → vx = 190*2896 >> 12 = 134, vy0 = -134
//     누적 세로 이동 = 4k^2 - 130k,  최고점 k = 16 에서 -1056 (= -66px) → py = 382
//     착지: k = 32 에서 -64, k = 33 에서 +66 → 33번째 프레임
//     가로: 33 * 134 = 4422 → px = (32*16 + 4422) >> 4 = 308
module tb_physics;
    localparam MAP_FILE = "test_map.mem";
    localparam integer T_NSCR = 2, T_SX = 32, T_SY = 448;
    `include "tb_harness.vh"

    integer n, i, fd, min_py;

    task traced_fly;
        output integer nf;
        begin
            nf = 0; min_py = py;
            while (state == 2'd2 && nf < 500) begin
                do_tick; nf = nf + 1;
                if (py < min_py) min_py = py;
                $fdisplay(fd, "%0d %0d %0d %0d %0d", nf, px, py, dut.vx, dut.vy);
            end
        end
    endtask

    initial begin
        fd = $fopen("physics_trace.txt", "w");
        repeat (4) @(negedge clk); rst = 0;
        do_tick;
        expect_eq("init state", state, 0);
        expect_eq("init angle", angle, 90);
        expect_eq("init px", px, 32);
        expect_eq("init py", py, 448);

        // ---- 각도 버튼: 누른 순간 1도, 15프레임 이상 누르면 프레임마다 1도 ----
        b_l = 1; do_tick; expect_eq("left: single step", angle, 91);
        repeat (14) do_tick; expect_eq("left: no repeat before 15 frames", angle, 91);
        repeat (5) do_tick;  expect_eq("left: auto repeat (1,1,1,2,1)", angle, 97);
        repeat (8) do_tick;  expect_eq("left: 5 deg per 4 frames", angle, 107);
        b_l = 0; do_tick;
        // 틱 사이에 지나간 짧은 누름도 한 번으로 센다
        @(negedge clk) b_r_rise = 1; @(negedge clk) b_r_rise = 0;
        do_tick; expect_eq("right: short tap", angle, 106);
        b_l = 1; repeat (150) do_tick; expect_eq("angle stops at 180", angle, 180);
        expect_eq("facing left", facing, 1);
        b_l = 0; b_r = 1; repeat (250) do_tick; expect_eq("angle stops at 0", angle, 0);
        expect_eq("facing right", facing, 0);
        b_r = 0; do_tick;

        // ---- 차지: 프레임당 +1, 63에서 포화, 상태 1 ----
        b_c = 1; do_tick; expect_eq("charge state", state, 1); expect_eq("charge 0", charge, 0);
        repeat (10) do_tick; expect_eq("charge 10", charge, 10);
        repeat (100) do_tick; expect_eq("charge saturates at 63", charge, 63);
        dut.angle = 90;
        b_c = 0; do_tick;
        expect_eq("air after release", state, 2);
        expect_eq("vertical: vy0", dut.vy, -190);
        expect_eq("vertical: vx0", dut.vx, 0);

        // ---- 수직 점프, 차지 63 ----
        $fdisplay(fd, "# vertical charge=63");
        traced_fly(n);
        expect_eq("vertical: peak py", min_py, 312);
        expect_eq("vertical: landing frame", n, 47);
        expect_eq("vertical: landing py", py, 448);
        expect_eq("vertical: landing px", px, 32);
        expect_eq("vertical: land flag", land, 1);
        expect_eq("vertical: idle after landing", state, 0);
        do_tick; expect_eq("land flag lasts one frame", land, 0);

        // ---- 45도 점프, 차지 63 ----
        start_jump(63, 45);
        expect_eq("45deg: vx0", dut.vx, 134);
        expect_eq("45deg: vy0", dut.vy, -134);
        $fdisplay(fd, "# 45deg charge=63");
        traced_fly(n);
        expect_eq("45deg: peak py", min_py, 382);
        expect_eq("45deg: landing frame", n, 33);
        expect_eq("45deg: landing px", px, 308);
        expect_eq("45deg: landing py", py, 448);

        // ---- 차지 0 (짧게 눌렀다 뗌): speed = 64 ----
        @(negedge clk) dut.angle = 90; b_c_rise = 1; @(negedge clk) b_c_rise = 0;
        do_tick; expect_eq("short tap enters charge", state, 1);
        do_tick; expect_eq("charge 0 jump: vy0", dut.vy, -64);
        fly(n);

        $fclose(fd);
        finish_tb;
    end
endmodule
