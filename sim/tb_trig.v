`timescale 1ns/1ps
// tb_trig — 삼각함수 두 버전을 0~180도 전부 계산해 $sin/$cos 와 비교한다 (명세 8장).
// 통과 기준: 최대 오차 3 LSB 이하, 90도에서 cos 가 정확히 0.
// trig_taylor_out.txt 에 "각도 sin cos" 를 쓴다 (tools/make_trig.py --rtl 로 그래프).
module tb_trig;
    reg clk = 0, rst = 1, start = 0;
    always #5 clk = ~clk;
    reg [7:0] angle = 0;
    wire signed [13:0] sin_r, cos_r, sin_t, cos_t;
    wire done_r, done_t;

    trig_rom    u_rom (.clk(clk), .rst(rst), .start(start), .angle(angle), .sin(sin_r), .cos(cos_r), .done(done_r));
    trig_taylor u_tay (.clk(clk), .rst(rst), .start(start), .angle(angle), .sin(sin_t), .cos(cos_t), .done(done_t));

    localparam real PI = 3.14159265358979323846;
    integer a, fd, errors = 0;
    integer es, ec, max_rom = 0, max_tay = 0, cyc_rom = 0, cyc_tay = 0, cyc;
    real rs, rc;

    function integer iabs; input integer v; iabs = (v < 0) ? -v : v; endfunction
    function integer rnd;  input real v;    rnd = (v < 0.0) ? -$rtoi(-v + 0.5) : $rtoi(v + 0.5); endfunction

    initial begin
        fd = $fopen("trig_taylor_out.txt", "w");
        repeat (3) @(negedge clk); rst = 0;
        for (a = 0; a <= 180; a = a + 1) begin
            @(negedge clk) angle = a; start = 1;
            @(negedge clk) start = 0;
            cyc = 1;
            while (!done_t) begin
                @(negedge clk); cyc = cyc + 1;
                if (done_r) cyc_rom = cyc;
            end
            cyc_tay = cyc;
            @(negedge clk);
            rs = $sin(a * PI / 180.0) * 4096.0;
            rc = $cos(a * PI / 180.0) * 4096.0;
            es = iabs(sin_r - rnd(rs)); ec = iabs(cos_r - rnd(rc));
            if (es > max_rom) max_rom = es;
            if (ec > max_rom) max_rom = ec;
            es = iabs(sin_t - rnd(rs)); ec = iabs(cos_t - rnd(rc));
            if (es > max_tay) max_tay = es;
            if (ec > max_tay) max_tay = ec;
            $fdisplay(fd, "%0d %0d %0d", a, sin_t, cos_t);
            if (a == 90 && (cos_r !== 0 || cos_t !== 0)) begin
                errors = errors + 1;
                $display("  FAIL cos(90): rom=%0d taylor=%0d", cos_r, cos_t);
            end
        end
        $fclose(fd);
        $display("ROM    max error %0d LSB (%0d clocks)", max_rom, cyc_rom);
        $display("Taylor max error %0d LSB (%0d clocks)", max_tay, cyc_tay);
        if (max_rom > 1) begin errors = errors + 1; $display("  FAIL ROM error"); end
        if (max_tay > 3) begin errors = errors + 1; $display("  FAIL Taylor error"); end
        if (errors == 0) $display("PASS"); else $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule
