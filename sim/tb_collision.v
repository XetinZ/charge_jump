`timescale 1ns/1ps
// tb_collision — 시험용 맵(sim/maps_test)에서 충돌, 화면 전환, 클리어를 시험한다 (명세 8장).
// 모든 프레임에서 상자가 막힌 타일과 겹치지 않는지 tb_harness 의 check_box 가 확인한다.
//
// 시험용 맵 화면 0:  바닥 row 29 / 벽 기둥 col 24 (row 22~28) / 슬래브 row 25, col 26~31
//                    1칸 틈 col 36 (기둥 col 35, 37, row 26~28) / 경계 발판 row 0, col 12~16
//            화면 1:  발판 row 22, col 24~30 / 목표 (row 21, col 30)
module tb_collision;
    localparam MAP_FILE = "test_map.mem";
    localparam integer T_NSCR = 2, T_SX = 32, T_SY = 448;
    `include "tb_harness.vh"

    integer n, i, seed, vx_before, got_bounce, bounce_px, bounce_vx, hit_py, saw_up, saw_down, jump_at;

    task place_idle;
        input integer s, ppx, ppy;
        begin
            @(negedge clk);
            dut.screen = s; dut.x = ppx * 16; dut.y = ppy * 16; dut.vx = 0; dut.vy = 0; dut.state = 2'd0;
            #1;
        end
    endtask

    // 날면서 벽 튕김 순간의 위치와 속도 변화를 기록한다
    task fly_watch_bounce;
        begin
            got_bounce = 0; n = 0;
            while (state == 2'd2 && n < 1000) begin
                vx_before = dut.vx;
                do_tick; n = n + 1;
                if (bounce && !got_bounce) begin
                    got_bounce = 1; bounce_px = px; bounce_vx = dut.vx;
                    expect_eq("bounce: vx = -vx/2", dut.vx, (-vx_before) >>> 1);
                end
            end
        end
    endtask

    initial begin
        seed = 20261124;
        repeat (4) @(negedge clk); rst = 0;
        do_tick;

        // ---- 1. 벽 (오른쪽으로 가다 기둥 col 24 의 왼쪽 면) ----
        place_idle(0, 320, 448);
        start_jump(40, 45);
        fly_watch_bounce;
        expect_eq("wall(right): bounced", got_bounce, 1);
        expect_eq("wall(right): snapped to tile edge", bounce_px, 24 * 16 - 16);
        expect_eq("wall(right): landing py", py, 448);

        // ---- 2. 벽 (왼쪽으로 가다 기둥의 오른쪽 면) ----
        place_idle(0, 27 * 16, 448);
        start_jump(20, 160);
        fly_watch_bounce;
        expect_eq("wall(left): bounced", got_bounce, 1);
        expect_eq("wall(left): snapped to tile edge", bounce_px, 25 * 16);

        // ---- 3. 화면 왼쪽 끝도 벽 ----
        place_idle(0, 20, 448);
        start_jump(30, 150);
        fly_watch_bounce;
        expect_eq("screen edge: bounced", got_bounce, 1);
        expect_eq("screen edge: px = 0", bounce_px, 0);

        // ---- 4. 천장 (슬래브 아랫면 = row 26 윗변) ----
        place_idle(0, 28 * 16, 448);
        start_jump(63, 90);
        hit_py = 9999; n = 0;
        while (state == 2'd2 && n < 500) begin
            do_tick; n = n + 1;
            if (py < hit_py) begin hit_py = py; if (py == 26 * 16) expect_eq("ceiling: vy = 0", dut.vy, 0); end
        end
        expect_eq("ceiling: snapped below", hit_py, 26 * 16);
        expect_eq("ceiling: lands back on floor", py, 448);

        // ---- 5. 발판 모서리 ----
        place_air(0, 32 * 16 - 15, 360, 0, 0); fly(n);       // 1픽셀만 걸쳐도 착지
        expect_eq("corner: 1px overlap lands on platform", py, 25 * 16 - 16);
        place_air(0, 32 * 16, 360, 0, 0); fly(n);            // 딱 붙어 지나감
        expect_eq("corner: flush pass falls to floor", py, 448);
        place_air(0, 32 * 16 + 4, 390, -32, 0); fly_watch_bounce;   // 옆면에 부딪힘
        expect_eq("corner: side bounce", got_bounce, 1);
        expect_eq("corner: side bounce px", bounce_px, 32 * 16);

        // ---- 6. 타일 1칸 틈 ----
        place_air(0, 36 * 16, 380, 0, 0); fly(n);
        expect_eq("gap: aligned falls to floor", py, 448);
        expect_eq("gap: px kept", px, 36 * 16);
        place_air(0, 36 * 16 + 3, 380, 0, 0); fly(n);
        expect_eq("gap: misaligned lands on pillars", py, 26 * 16 - 16);

        // ---- 7. 무작위 점프 400회: 침범·통과가 없어야 한다 ----
        place_idle(0, 32, 448);
        for (i = 0; i < 400; i = i + 1) begin
            start_jump({$random(seed)} % 64, {$random(seed)} % 181);
            fly(n);
            if (state != 2'd0) begin pulse_reset; end        // 클리어에 닿으면 리셋하고 계속
        end
        expect_eq("per-frame move < 16px (x)", max_dx < 16, 1);
        expect_eq("per-frame move < 16px (y)", max_dy < 16, 1);
        $display("  random jumps: max move dx=%0d dy=%0d px/frame", max_dx, max_dy);

        // ---- 8. 화면 전환: 위로 넘어가 경계 발판(화면 0 의 row 0)에 착지 ----
        place_air(0, 120, 24, 48, -150);
        saw_up = 0; n = 0;
        while (state == 2'd2 && n < 500) begin
            do_tick; n = n + 1;
            if (screen == 1 && prev_scr == 0) begin
                saw_up = 1;
                expect_eq("screen up: y adjusted by 480", (py - prev_py) > 400, 1);
            end
        end
        expect_eq("screen up: happened", saw_up, 1);
        expect_eq("boundary platform: screen 1", screen, 1);
        expect_eq("boundary platform: py = 464", py, 464);
        expect_eq("boundary platform: idle", state, 0);

        // 발판에서 옆으로 뛰어내리면 화면 0 으로 돌아와 바닥에 착지
        start_jump(40, 30);
        saw_down = 0; n = 0;
        while (state == 2'd2 && n < 500) begin
            do_tick; n = n + 1;
            if (screen == 0 && prev_scr == 1) begin saw_down = 1; expect_eq("screen down: fell flag", fell, 1); end
            else expect_eq("fell flag only on the falling frame", fell, 0);
        end
        expect_eq("screen down: happened", saw_down, 1);
        expect_eq("screen down: lands on floor", py, 448);

        // 맨 위 화면의 위는 막힘
        place_air(1, 100, 20, 0, -150);
        do_tick; do_tick; do_tick;
        expect_eq("top ceiling: py = 0", py, 0);
        expect_eq("top ceiling: screen kept", screen, 1);
        fly(n);
        expect_eq("fall from top to screen 0 floor", screen * 1000 + py, 448);

        // ---- 9. 클리어: 목표 타일에 닿으면 상태 3, 리셋 전까지 유지 ----
        place_air(1, 30 * 16, 300, 0, 0); fly(n);
        expect_eq("clear state", state, 3);
        hit_py = py;                                         // 목표 타일 안에서 그대로 멈춘다
        b_c = 1; b_l = 1; repeat (30) do_tick; b_c = 0; b_l = 0; repeat (5) do_tick;
        expect_eq("clear persists", state, 3);
        expect_eq("clear: frozen", py, hit_py);
        pulse_reset;
        expect_eq("reset: idle", state, 0);
        expect_eq("reset: screen 0", screen, 0);
        expect_eq("reset: px", px, 32);
        expect_eq("reset: py", py, 448);
        expect_eq("reset: angle 90", angle, 90);

        finish_tb;
    end
endmodule
