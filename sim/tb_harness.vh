// tb_harness.vh — game_core 테스트벤치 공통부.
// include 하기 전에 localparam MAP_FILE, T_NSCR, T_SX, T_SY 를 정의한다.
// 버튼은 input_sync 를 거치지 않고 직접 넣고, 틱은 do_tick 으로 한 프레임씩 진행한다.

reg clk = 0, rst = 1, tick = 0;
always #5 clk = ~clk;

reg b_c = 0, b_l = 0, b_r = 0;
reg b_c_rise = 0, b_l_rise = 0, b_r_rise = 0, b_rs_rise = 0;

wire [13:0] map_addr;
wire [1:0]  map_data;
wire        trig_start, trig_done;
wire signed [13:0] trig_sin, trig_cos;
wire signed [15:0] gx, gy;
wire [2:0] screen;
wire [5:0] charge;
wire [7:0] angle;
wire [1:0] state;
wire       facing, land, bounce, fell, rising, send;

map_rom  #(.MEM_FILE(MAP_FILE)) u_map  (.clk(clk), .addr(map_addr), .data(map_data));
trig_rom u_trig (.clk(clk), .rst(rst), .start(trig_start), .angle(angle),
                 .sin(trig_sin), .cos(trig_cos), .done(trig_done));
game_core #(.OV_NUM_SCREENS(T_NSCR), .OV_START_SCREEN(0), .OV_START_X(T_SX), .OV_START_Y(T_SY)) dut (
    .clk(clk), .rst(rst), .tick(tick),
    .btn_charge(b_c), .btn_charge_rise(b_c_rise),
    .btn_left(b_l),   .btn_left_rise(b_l_rise),
    .btn_right(b_r),  .btn_right_rise(b_r_rise),
    .btn_reset_rise(b_rs_rise),
    .map_addr(map_addr), .map_data(map_data),
    .trig_start(trig_start), .trig_sin(trig_sin), .trig_cos(trig_cos), .trig_done(trig_done),
    .x(gx), .y(gy), .screen(screen), .charge(charge), .angle(angle),
    .state(state), .facing(facing), .land(land), .bounce(bounce), .fell(fell), .rising(rising), .send(send));

wire signed [11:0] px = gx[15:4];
wire signed [11:0] py = gy[15:4];

integer frame = 0, errors = 0, checks = 0;
integer max_dx = 0, max_dy = 0;
integer prev_px, prev_py, prev_scr, prev_state;

// ---- 검사용 기준: 픽셀 (qx, qy) 가 막힌 타일인가 (명세 5장의 화면 밖 규칙 포함) ----
function is_solid;
    input integer s, qx, qy;
    integer tx, ty, ss;
    begin
        tx = (qx >= 0) ? qx / 16 : -((15 - qx) / 16);
        ty = (qy >= 0) ? qy / 16 : -((15 - qy) / 16);
        ss = s;
        if (ty < 0)       begin ss = s + 1; ty = ty + 30; end
        else if (ty > 29) begin ss = s - 1; ty = ty - 30; end
        if (tx < 0 || tx > 39 || ss < 0 || ss >= dut.NSCR) is_solid = 1;
        else is_solid = (u_map.mem[(ss << 11) | (ty << 6) | tx] == 2'd1);
    end
endfunction

task expect_eq;
    input [8*96-1:0] name;
    input integer got, want;
    begin
        checks = checks + 1;
        if (got !== want) begin
            errors = errors + 1;
            $display("  FAIL %0s: got %0d, want %0d (frame %0d)", name, got, want, frame);
        end
    end
endtask

// 매 프레임: 상자의 네 모서리가 막힌 타일과 겹치지 않아야 한다
task check_box;
    begin
        if (is_solid(screen, px, py)      || is_solid(screen, px + 15, py) ||
            is_solid(screen, px, py + 15) || is_solid(screen, px + 15, py + 15)) begin
            errors = errors + 1;
            $display("  FAIL box overlaps solid tile: screen=%0d px=%0d py=%0d (frame %0d)", screen, px, py, frame);
        end
    end
endtask

task do_tick;
    begin
        prev_px = px; prev_py = py; prev_scr = screen; prev_state = state;
        @(negedge clk) tick = 1;
        @(negedge clk) tick = 0;
        @(posedge send);
        @(negedge clk);
        frame = frame + 1;
        check_box;
        if (screen == prev_scr && prev_state == 2) begin
            if (px - prev_px > max_dx) max_dx = px - prev_px;
            if (prev_px - px > max_dx) max_dx = prev_px - px;
            if (py - prev_py > max_dy) max_dy = py - prev_py;
            if (prev_py - py > max_dy) max_dy = prev_py - py;
        end
    end
endtask

task pulse_reset;
    begin
        @(negedge clk) b_rs_rise = 1;
        @(negedge clk) b_rs_rise = 0;
        do_tick;
    end
endtask

// 대기 상태에서 차지 ch, 각도 ang 으로 점프 (각도는 레지스터에 직접 써 넣는다). 점프 틱까지 진행.
task start_jump;
    input integer ch, ang;
    integer i;
    begin
        dut.angle = ang;
        b_c = 1;
        for (i = 0; i <= ch; i = i + 1) do_tick;
        b_c = 0;
        do_tick;
    end
endtask

// 공중 상태가 끝날 때까지 진행하고 걸린 프레임 수를 돌려준다
task fly;
    output integer n;
    begin
        n = 0;
        while (state == 2'd2 && n < 2000) begin do_tick; n = n + 1; end
        if (n >= 2000) begin errors = errors + 1; $display("  FAIL never landed"); end
    end
endtask

// 시험용: 원하는 위치·속도로 공중 상태에 놓는다 (속도는 소수 4비트 원시값)
task place_air;
    input integer s, ppx, ppy, pvx, pvy;
    begin
        @(negedge clk);
        dut.screen = s; dut.x = ppx * 16; dut.y = ppy * 16;
        dut.vx = pvx;   dut.vy = pvy;     dut.state = 2'd2;
        #1;
    end
endtask

task finish_tb;
    begin
        if (errors == 0) $display("PASS (%0d checks, %0d frames)", checks, frame);
        else             $display("FAILED: %0d errors", errors);
        $finish;
    end
endtask
