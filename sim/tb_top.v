`timescale 1ns/1ps
// tb_top — top 전체를 버튼과 UART 핀으로만 시험한다 (통합).
// 보드와 같은 1MHz 클록으로 돌린다. UART 출력을 받아 패킷을 해석하고,
// 고정 패킷 모드 → 각도 조절 → 차지 → 점프 → 착지 → 테일러 모드 점프 → 리셋 순서로 확인한다.
module tb_top;
    localparam integer F = 1_000_000;
    localparam integer DIV = 52;                // round(1e6 / 19200)
    reg clk = 0;
    always #5 clk = ~clk;

    reg btn_charge = 0, btn_left = 0, btn_right = 0, btn_reset = 0, dip_trig = 0, dip_test = 1;
    reg dip_uart_sel = 0, dip_probe = 0;
    wire [7:0] led;
    wire servo;
    wire uart_f6, uart_c6;
    // PC 쪽(USB 칩) 흉내: 확인 모드 시험에서만 C6 을 구동한다
    reg c6_drv_en = 0, c6_drv = 1;
    assign uart_c6 = c6_drv_en ? c6_drv : 1'bz;
    pullup (uart_f6);                           // XDC 의 PULLUP 과 같게
    pullup (uart_c6);
    integer f6_low_while_c6 = 0;                // C6 로 보내는 동안 F6 이 0 으로 내려간 횟수 (0 이어야 함)
    always @(negedge uart_f6) if (dip_uart_sel) f6_low_while_c6 = f6_low_while_c6 + 1;
    // 수신기는 FPGA 가 고른 송신 핀을 본다 (High-Z 면 정지 상태 1)
    wire txd_raw = dip_uart_sel ? uart_c6 : uart_f6;
    wire txd = txd_raw;

    top #(.CLK_HZ_OVERRIDE(F)) dut (
        .clk(clk), .btn_charge(btn_charge), .btn_left(btn_left), .btn_right(btn_right),
        .btn_reset(btn_reset), .dip_trig(dip_trig), .dip_test(dip_test),
        .dip_uart_sel(dip_uart_sel), .dip_probe(dip_probe),
        .led(led), .servo(servo), .uart_f6(uart_f6), .uart_c6(uart_c6));

    integer errors = 0, checks = 0;
    task expect_eq;
        input [8*64-1:0] name; input integer got, want;
        begin
            checks = checks + 1;
            if (got !== want) begin errors = errors + 1; $display("  FAIL %0s: got %0d, want %0d", name, got, want); end
        end
    endtask

    // ---- UART 수신 + 패킷 해석 (viewer.py 와 같은 절차) ----
    reg [7:0] pk [0:10];
    integer nb = 0, npkt = 0, nbad = 0, i;
    reg [7:0] sh, cs;
    reg signed [15:0] p_x, p_y;
    reg [7:0] p_screen, p_charge, p_angle, p_status;
    integer n_land = 0, n_bounce = 0, min_y = 9999, max_leds = 0;
    event pkt_ev;

    function integer popcount; input [7:0] v; integer k; begin
        popcount = 0; for (k = 0; k < 8; k = k + 1) popcount = popcount + v[k]; end
    endfunction

    always begin
        @(negedge txd);
        repeat (DIV + DIV / 2) @(posedge clk);
        for (i = 0; i < 8; i = i + 1) begin sh[i] = txd; repeat (DIV) @(posedge clk); end
        if ((nb == 0 && sh !== 8'hAA) || (nb == 1 && sh !== 8'h55)) begin
            nbad = nbad + 1; nb = 0;
        end else begin
            pk[nb] = sh; nb = nb + 1;
            if (nb == 11) begin
                nb = 0;
                cs = pk[2] ^ pk[3] ^ pk[4] ^ pk[5] ^ pk[6] ^ pk[7] ^ pk[8] ^ pk[9];
                if (cs !== pk[10]) nbad = nbad + 1;
                else begin
                    p_x = {pk[2], pk[3]}; p_y = {pk[4], pk[5]};
                    p_screen = pk[6]; p_charge = pk[7]; p_angle = pk[8]; p_status = pk[9];
                    npkt = npkt + 1;
                    if (p_status[4]) n_land = n_land + 1;
                    if (p_status[5]) n_bounce = n_bounce + 1;
                    if (p_y < min_y) min_y = p_y;
                    if (popcount(led) > max_leds) max_leds = popcount(led);
                    -> pkt_ev;
                end
            end
        end
    end

    task wait_pkts; input integer n; begin repeat (n) @(pkt_ev); end endtask


    integer guard, start_x, start_y, pk0;

    initial begin
        // ---- 1. 고정 패킷 모드 ----
        wait_pkts(5);
        expect_eq("test packet x", p_x, 320);
        expect_eq("test packet y", p_y, 240);
        expect_eq("test packet charge", p_charge, 32);
        expect_eq("test packet angle", p_angle, 45);
        expect_eq("test packet status", p_status, 1);

        // ---- 2. 게임 모드: 시작 상태 ----
        dip_test = 0;
        wait_pkts(3);
        start_x = p_x; start_y = p_y;
        expect_eq("start state idle", p_status[1:0], 0);
        expect_eq("start angle", p_angle, 90);
        expect_eq("start screen", p_screen, 0);
        expect_eq("leds off when idle", led, 0);

        // ---- 3. 오른쪽 버튼으로 각도를 75도까지 ----
        btn_right = 1; #3000 btn_right = 0; #7000 btn_right = 1;    // 접점 떨림 흉내
        guard = 0;
        while (p_angle > 75 && guard < 200) begin wait_pkts(1); guard = guard + 1; end
        btn_right = 0;
        wait_pkts(2);
        expect_eq("angle reached 75", p_angle, 75);
        expect_eq("facing right", p_status[2], 0);

        // ---- 4. 차지 (최대까지) 후 점프 ----
        btn_charge = 1;
        wait_pkts(3);
        expect_eq("charging state", p_status[1:0], 1);
        wait_pkts(75);
        expect_eq("charge saturated", p_charge, 63);
        expect_eq("all leds during full charge", max_leds, 8);
        min_y = 9999; n_land = 0;
        btn_charge = 0;
        wait_pkts(3);
        expect_eq("air state", p_status[1:0], 2);
        expect_eq("leds off in air", led, 0);
        guard = 0;
        while (p_status[1:0] == 2 && guard < 300) begin wait_pkts(1); guard = guard + 1; end
        expect_eq("landed -> idle", p_status[1:0], 0);
        expect_eq("land flag seen exactly once", n_land, 1);
        expect_eq("jumped higher than 100px", (start_y - min_y) > 100, 1);
        expect_eq("moved right", p_x > start_x, 1);
        $display("  jump 1 (ROM): landed at (%0d, %0d), peak y %0d", p_x, p_y, min_y);

        // 패킷 값이 코어 레지스터와 같은가
        wait_pkts(1);
        expect_eq("packet x == core x", p_x, dut.u_core.x >>> 4);
        expect_eq("packet y == core y", p_y, dut.u_core.y >>> 4);

        // ---- 5. 테일러 모드로 한 번 더 ----
        dip_trig = 1;
        wait_pkts(2);
        expect_eq("status shows taylor mode", p_status[3], 1);
        start_y = p_y; min_y = 9999; n_land = 0;
        btn_charge = 1; wait_pkts(40); btn_charge = 0;
        wait_pkts(3);
        guard = 0;
        while (p_status[1:0] == 2 && guard < 300) begin wait_pkts(1); guard = guard + 1; end
        expect_eq("taylor jump landed", n_land, 1);
        expect_eq("taylor jump rose", (start_y - min_y) > 20, 1);
        $display("  jump 2 (Taylor): landed at (%0d, %0d), peak y %0d", p_x, p_y, min_y);

        // ---- 6. 리셋 버튼 ----
        btn_reset = 1; wait_pkts(3); btn_reset = 0; wait_pkts(2);
        expect_eq("reset x", p_x, dut.u_core.INIT_X);
        expect_eq("reset y", p_y, dut.u_core.INIT_Y);
        expect_eq("reset angle", p_angle, 90);

        // ---- 7. 통신 품질 ----
        expect_eq("no bad packets", nbad, 0);
        pk0 = npkt; #(10 * (F / 60) * 10);               // 10 프레임 (클록 주기 10ns)
        expect_eq("one packet per frame", (npkt - pk0) >= 9 && (npkt - pk0) <= 11, 1);

        // ---- 8. UART 핀 선택: C6 으로 송신, F6 은 High-Z ----
        wait (!dut.u_pkt.busy); dip_uart_sel = 1; #(10 * 20);
        expect_eq("sel=1: F6 released (pulled up)", dut.uart_f6 === 1'b1 && !(!dut.probe_mode && !dut.uart_sel), 1);
        pk0 = npkt; wait_pkts(3);
        expect_eq("sel=1: packets on C6", npkt - pk0, 3);
        expect_eq("sel=1: no bad packets", nbad, 0);
        expect_eq("sel=1: F6 stays idle (not driven)", f6_low_while_c6, 0);

        // ---- 9. 확인 모드: 두 핀 모두 High-Z, PC 신호가 들어오는 핀의 LED 가 켜짐 ----
        dip_probe = 1; #(10 * (F / 4));                  // 0.25초: 앞 단계 송신의 LED 표시가 꺼지기를 기다림
        expect_eq("probe: FPGA drives neither pin", dut.probe_mode, 1);
        expect_eq("probe: both pins idle high", {uart_f6, uart_c6}, 2'b11);
        expect_eq("probe: no activity before PC sends", led[1:0], 0);
        c6_drv_en = 1;
        repeat (20) begin c6_drv = 0; #(10 * 52); c6_drv = 1; #(10 * 52); end
        expect_eq("probe: LED2 (C6 activity) on", led[1], 1);
        expect_eq("probe: LED1 (F6 activity) off", led[0], 0);
        expect_eq("probe: LED8 = C6 level", led[7], 1);
        #(10 * (F / 5) + 10 * 1000);
        expect_eq("probe: LED2 off after 0.2s idle", led[1], 0);
        c6_drv_en = 0; dip_probe = 0; dip_uart_sel = 0;

        if (errors == 0) $display("PASS (%0d checks, %0d packets)", checks, npkt);
        else             $display("FAILED: %0d errors", errors);
        $finish;
    end

    initial begin #(64'd400_000_000); $display("FAILED: timeout"); $finish; end
endmodule
