`timescale 1ns/1ps
// tb_periph — tick_gen, input_sync, led_gauge, servo_pwm.
module tb_periph;
    localparam integer CLK_HZ = 2_000_000;      // 시뮬레이션 단축용
    reg clk = 0, rst = 1;
    always #5 clk = ~clk;
    integer errors = 0, i;

    // ---- tick_gen ----
    wire tick_game, tick_us;
    tick_gen #(.CLK_HZ(CLK_HZ), .TICK_HZ(60)) u_tick (.clk(clk), .rst(rst), .tick_game(tick_game), .tick_us(tick_us));
    integer cyc = 0, last_game = 0, game_period = 0, us_count = 0;
    always @(posedge clk) begin
        cyc <= cyc + 1;
        if (tick_game) begin game_period <= cyc - last_game; last_game <= cyc; end
        if (tick_us) us_count <= us_count + 1;
    end

    // ---- input_sync ----
    reg btn = 0;
    wire level, rise, fall;
    input_sync #(.CLK_HZ(CLK_HZ), .DEBOUNCE_MS(10)) u_in (.clk(clk), .rst(rst), .in(btn), .level(level), .rise(rise), .fall(fall));
    integer n_rise = 0, n_fall = 0;
    always @(posedge clk) begin if (rise) n_rise <= n_rise + 1; if (fall) n_fall <= n_fall + 1; end

    task bouncy;                                   // 떨림 뒤에 v 로 안정
        input v;
        begin
            for (i = 0; i < 12; i = i + 1) begin btn = ~btn; repeat (200 + 150 * i) @(negedge clk); end
            btn = v;
        end
    endtask

    // ---- led_gauge ----
    reg charging = 0;
    reg [5:0] charge = 0;
    wire [7:0] led;
    led_gauge u_led (.clk(clk), .rst(rst), .tick(tick_game), .charging(charging), .charge(charge), .led(led));

    // ---- servo_pwm ----
    reg [7:0] angle = 8'd90;
    wire pwm;
    servo_pwm u_servo (.clk(clk), .rst(rst), .tick_us(tick_us), .angle(angle), .pwm(pwm));
    // 클록 2MHz, 주기 10ns → 1us = 20ns
    integer last_high = 0, last_period = 0;
    time t_rise = 0;
    always @(posedge pwm) begin last_period = ($time - t_rise) / 20; t_rise = $time; end
    always @(negedge pwm) last_high = ($time - t_rise) / 20;

    task expect_eq;
        input [8*32-1:0] name; input integer got, want;
        begin
            if (got !== want) begin errors = errors + 1; $display("  FAIL %0s: got %0d, want %0d", name, got, want); end
        end
    endtask

    task servo_check;
        input [7:0] a; input integer want_us;
        begin
            angle = a;
            repeat (3) @(posedge pwm);
            @(negedge clk); @(negedge clk);
            expect_eq("servo period(us)", last_period, 20000);
            expect_eq("servo width(us)", last_high, want_us);
        end
    endtask

    initial begin
        repeat (4) @(negedge clk); rst = 0;

        // 버튼: 떨림이 있어도 한 번 누를 때 rise 한 번, 뗄 때 fall 한 번
        repeat (3) begin
            bouncy(1); repeat (30000) @(negedge clk);
            bouncy(0); repeat (30000) @(negedge clk);
        end
        expect_eq("rise count", n_rise, 3);
        expect_eq("fall count", n_fall, 3);
        // 10ms 보다 짧은 잡음은 무시
        btn = 1; repeat (15000) @(negedge clk); btn = 0; repeat (30000) @(negedge clk);
        expect_eq("rise after glitch", n_rise, 3);

        expect_eq("game tick period", game_period, CLK_HZ / 60);

        // LED: charge[5:3]+1 개, 차지 상태가 아니면 꺼짐
        charging = 1;
        for (i = 0; i < 63; i = i + 1) begin
            charge = i; repeat (2) @(negedge clk);
            expect_eq("led bar", led, (1 << (i / 8 + 1)) - 1);
        end
        charging = 0; repeat (2) @(negedge clk);
        expect_eq("led off", led, 0);

        // 서보: 0도 0.7ms, 90도 1.5ms, 180도 2.3ms, 주기 20ms (7주차 자료)
        servo_check(8'd0,    700);
        servo_check(8'd90,  1500);
        servo_check(8'd180, 2300);

        if (errors == 0) $display("PASS"); else $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule
