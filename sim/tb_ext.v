`timescale 1ns/1ps
// tb_ext — 확장 기능: seg_timer (8자리 시간), piezo_sfx (효과음), lcd_taunt (텍스트 LCD).
module tb_ext;
    reg clk = 0, rst = 1;
    always #5 clk = ~clk;                        // 클록 1개 = 1us 로 본다 (tick_us 는 항상 1)
    integer errors = 0, checks = 0, i;

    task expect_eq;
        input [8*64-1:0] name; input integer got, want;
        begin
            checks = checks + 1;
            if (got !== want) begin errors = errors + 1; $display("  FAIL %0s: got %0d, want %0d", name, got, want); end
        end
    endtask

    // ================= seg_timer =================
    localparam integer T_CLK = 100_000;          // 0.01초 = 1000클록
    reg run = 0, clear = 0, off = 0, t_cal = 0;
    wire [7:0] ar_seg, ar_sel;
    seg_timer #(.CLK_HZ(T_CLK), .S0_IS_LEFT(1)) u_timer (
        .clk(clk), .rst(rst), .run(run), .clear(clear), .off(off),
        .cal(t_cal), .cal_ch(3'd5), .cal_lvl(2'd2), .cal_val(8'd137), .ar_seg(ar_seg), .ar_sel(ar_sel));

    // 스캔을 받아 왼쪽부터 8자리의 패턴을 모은다 (S0 = 맨 왼쪽)
    reg [7:0] shown [0:7];
    wire [7:0] nsel = ~ar_sel;
    integer sel_errors = 0;
    always @(posedge clk) begin
        for (i = 0; i < 8; i = i + 1) if (ar_sel == ~(8'h01 << i)) shown[i] <= ar_seg;
        if (!rst && !off && (^ar_sel === 1'bx || (nsel & (nsel - 8'd1)) != 8'd0))
            sel_errors = sel_errors + 1;         // 한 번에 한 자리만 선택되어야 한다
    end
    function integer digit_of;                   // 패턴 → 숫자 (-1 = 꺼짐, -2 = 모름)
        input [7:0] p;
        case (p[7:1])
            7'b1111110: digit_of = 0;  7'b0110000: digit_of = 1;  7'b1101101: digit_of = 2;
            7'b1111001: digit_of = 3;  7'b0110011: digit_of = 4;  7'b1011011: digit_of = 5;
            7'b1011111: digit_of = 6;  7'b1110000: digit_of = 7;  7'b1111111: digit_of = 8;
            7'b1111011: digit_of = 9;  7'b0000000: digit_of = -1; default: digit_of = -2;
        endcase
    endfunction
    task expect_display;                         // 왼쪽부터 8자리 (-1 = 꺼짐), 소수점은 6번째 자리 뒤
        input integer d0, d1, d2, d3, d4, d5, d6, d7;
        begin
            repeat (2000) @(negedge clk);        // 스캔이 한 바퀴 돌기를 기다림
            expect_eq("timer digit 1", digit_of(shown[0]), d0);
            expect_eq("timer digit 2", digit_of(shown[1]), d1);
            expect_eq("timer digit 3", digit_of(shown[2]), d2);
            expect_eq("timer digit 4", digit_of(shown[3]), d3);
            expect_eq("timer digit 5", digit_of(shown[4]), d4);
            expect_eq("timer digit 6", digit_of(shown[5]), d5);
            expect_eq("timer digit 7", digit_of(shown[6]), d6);
            expect_eq("timer digit 8", digit_of(shown[7]), d7);
            expect_eq("decimal point after seconds", {shown[4][0], shown[5][0], shown[6][0]}, 3'b010);
        end
    endtask

    // ================= piezo_sfx =================
    reg tick = 0, mute = 0;
    reg [1:0] state = 0;
    reg [5:0] charge = 0;
    wire piezo;
    piezo_sfx u_piezo (.clk(clk), .rst(rst), .tick_us(1'b1), .tick(tick), .state(state),
                       .charge(charge), .mute(mute), .piezo(piezo));
    integer half_us = 0, edges = 0;
    time t_edge = 0;
    always @(piezo) begin half_us = ($time - t_edge) / 10; t_edge = $time; edges = edges + 1; end
    task do_tick; begin @(negedge clk) tick = 1; @(negedge clk) tick = 0; end endtask

    // ================= lcd_taunt =================
    reg fell = 0, cleared = 0, plain = 0;
    reg [2:0] screen = 0;
    wire lcd_rs, lcd_rw, lcd_e;
    wire [7:0] lcd_d;
    lcd_taunt #(.TAUNT_FRAMES(30)) u_lcd (
        .clk(clk), .rst(rst), .tick_us(1'b1), .tick(tick), .fell(fell), .screen(screen),
        .cleared(cleared), .plain(plain), .lcd_rs(lcd_rs), .lcd_rw(lcd_rw), .lcd_e(lcd_e), .lcd_d(lcd_d));

    // HD44780 흉내: E 가 내려갈 때 받아들인다
    reg [7:0] ddram [0:127];
    reg [7:0] cgram [0:63];
    reg [6:0] addr = 0;
    reg       in_cgram = 0, display_on = 0;
    integer   n_func = 0, e_high_errors = 0;
    time      t_e_rise = 0;
    always @(posedge lcd_e) t_e_rise = $time;
    always @(negedge lcd_e) begin
        if (!rst && $time - t_e_rise < 20) e_high_errors = e_high_errors + 1;     // E 폭 2us 이상 (클록 1개 = 10ns = 1us)
        if (!lcd_rs) begin
            if (lcd_d[7])            begin addr = lcd_d[6:0]; in_cgram = 0; end
            else if (lcd_d[6])       begin addr = {1'b0, lcd_d[5:0]}; in_cgram = 1; end
            else if (lcd_d == 8'h38) n_func = n_func + 1;
            else if (lcd_d == 8'h0C) display_on = 1;
        end else begin
            if (in_cgram) cgram[addr[5:0]] = lcd_d; else ddram[addr] = lcd_d;
            addr = addr + 1;
        end
    end
    task expect_lines;                           // '#' = 사용자 문자 1, '$' = 사용자 문자 2
        input [127:0] l1, l2;
        reg [7:0] w;
        integer k, bad;
        begin
            bad = 0;
            for (k = 0; k < 16; k = k + 1) begin
                w = l1[8 * (15 - k) +: 8]; if (w == "#") w = 8'h01; if (w == "$") w = 8'h02;
                if (ddram[k] !== w) bad = bad + 1;
                w = l2[8 * (15 - k) +: 8]; if (w == "#") w = 8'h01; if (w == "$") w = 8'h02;
                if (ddram[7'h40 + k] !== w) bad = bad + 1;
            end
            checks = checks + 1;
            if (bad != 0) begin
                errors = errors + 1;
                $write("  FAIL lcd text (%0d chars differ). line 1 on screen: ", bad);
                for (k = 0; k < 16; k = k + 1) $write("%c", ddram[k] < 8'h20 ? "?" : ddram[k]);
                $write("\n");
            end
        end
    endtask

    // ================= cds_light + AD7908 =================
    wire adc_cs, adc_sclk, adc_din, adc_dout;
    reg  [7:0] vin [0:7];
    reg  [2:0] l_screen = 0;
    reg        l_en = 1;
    wire [1:0] dark, lvl;
    wire [2:0] cal_ch;
    wire [7:0] cal_val, light_val;
    ad7908_model u_adc (.cs(adc_cs), .sclk(adc_sclk), .din(adc_din), .dout(adc_dout),
        .vin0(vin[0]), .vin1(vin[1]), .vin2(vin[2]), .vin3(vin[3]),
        .vin4(vin[4]), .vin5(vin[5]), .vin6(vin[6]), .vin7(vin[7]));
    cds_light #(.TICK_HZ(60), .LIGHT_CH(5), .LIGHT_INV(0), .T1(64), .T2(128), .T3(192), .HYST(6),
                .DARK_SCREEN(2)) u_cds (
        .clk(clk), .rst(rst), .tick(tick), .screen(l_screen), .enable(l_en),
        .adc_cs(adc_cs), .adc_sclk(adc_sclk), .adc_din(adc_din), .adc_dout(adc_dout),
        .dark(dark), .cal_ch(cal_ch), .cal_val(cal_val), .light_val(light_val), .level(lvl));
    task set_light; input [7:0] x; begin vin[5] = x; repeat (2000) @(negedge clk); do_tick; do_tick; end endtask

    initial begin
        for (i = 0; i < 8; i = i + 1) vin[i] = 8'd10 + 8'd20 * i;
        repeat (4) @(negedge clk); rst = 0;

        // ---- ADC: 8채널을 모두 읽어 제 자리에 넣는다 ----
        repeat (3000) @(negedge clk);
        expect_eq("adc: ch0", u_cds.val[0], 10);
        expect_eq("adc: ch3", u_cds.val[3], 70);
        expect_eq("adc: ch7", u_cds.val[7], 150);
        expect_eq("adc: light channel (5)", light_val, 110);
        expect_eq("adc: control word as intended", u_adc.bad_ctrl, 0);
        expect_eq("adc: power-up frames done", u_adc.ones_frames, 2);
        expect_eq("adc: CS falls while SCLK high", u_adc.cs_while_sclk_low, 0);
        vin[3] = 8'd201; repeat (1000) @(negedge clk);
        expect_eq("adc: follows a changed input", u_cds.val[3], 201);

        // ---- 밝기 단계와 어둠: 우주(화면 2)에서만 ----
        set_light(250); expect_eq("bright: level 3", lvl, 3); expect_eq("bright: dark 0", dark, 0);
        l_screen = 2; set_light(250); expect_eq("space bright: dark 0", dark, 0);
        set_light(150); expect_eq("space 150: dark 1", dark, 1);
        set_light(100); expect_eq("space 100: dark 2", dark, 2);
        set_light(20);  expect_eq("space 20: dark 3", dark, 3);
        set_light(66);  expect_eq("hysteresis: 66 stays dark 3", dark, 3);
        set_light(72);  expect_eq("hysteresis: 72 goes dark 2", dark, 2);
        set_light(60);  expect_eq("hysteresis: 60 stays dark 2", dark, 2);
        set_light(55);  expect_eq("hysteresis: 55 goes dark 3", dark, 3);
        l_screen = 1; do_tick; repeat (3) @(negedge clk);
        expect_eq("other screen: dark 0", dark, 0);
        l_screen = 2; l_en = 0; do_tick; repeat (3) @(negedge clk);
        expect_eq("ext off: dark 0", dark, 0);
        l_en = 1; l_screen = 0;
        // 보정 표시: 1.5초(90틱)마다 채널이 바뀐다
        expect_eq("cal: starts at ch0... value", cal_val, u_cds.val[cal_ch]);
        i = cal_ch; repeat (90) do_tick;
        expect_eq("cal: next channel after 90 ticks", cal_ch, (i + 1) % 8);


        // ---- 타이머: 0.00 → 12.34 → 멈춤 → 지움, 앞자리 0 은 꺼짐 ----
        expect_display(-1, -1, -1, -1, -1, 0, 0, 0);
        run = 1; repeat (1234 * 1000) @(negedge clk); run = 0;
        expect_display(-1, -1, -1, -1, 1, 2, 3, 4);
        expect_display(-1, -1, -1, -1, 1, 2, 3, 4);                    // 멈춘 동안 그대로
        off = 1; repeat (2000) @(negedge clk);
        expect_eq("timer off: no digit selected", ar_sel, 8'hFF);
        off = 0;
        // 보정 표시: [채널 5] . . [단계 2] . [137]
        t_cal = 1; repeat (2000) @(negedge clk);
        expect_eq("cal display: ch", digit_of(shown[0]), 5);
        expect_eq("cal display: level", digit_of(shown[3]), 2);
        expect_eq("cal display: value hundreds", digit_of(shown[5]), 1);
        expect_eq("cal display: value tens", digit_of(shown[6]), 3);
        expect_eq("cal display: value ones", digit_of(shown[7]), 7);
        expect_eq("cal display: blanks", {digit_of(shown[1]), digit_of(shown[2]), digit_of(shown[4])} == {-32'sd1, -32'sd1, -32'sd1}, 1);
        t_cal = 0;
        @(negedge clk) clear = 1; @(negedge clk) clear = 0;
        expect_display(-1, -1, -1, -1, -1, 0, 0, 0);
        expect_eq("one digit selected at a time", sel_errors, 0);

        // ---- 피에조: 차지 음 높이, 무음, 점프음 ----
        expect_eq("piezo silent when idle", piezo, 0);
        state = 1; charge = 0;  repeat (6000) @(negedge clk);
        expect_eq("charge 0: half period 1666us (300Hz)", half_us, 1666);
        charge = 63;            repeat (6000) @(negedge clk);
        expect_eq("charge 63: half period 658us (760Hz)", half_us, 658);
        mute = 1; repeat (10) @(negedge clk); edges = 0; repeat (5000) @(negedge clk);
        expect_eq("mute: no sound", edges, 0);
        mute = 0;
        do_tick; state = 2; do_tick;                                   // 차지 → 공중 = 점프
        repeat (3000) @(negedge clk);
        expect_eq("jump sound starts (half period 520us)", half_us, 520);
        repeat (10) begin do_tick; repeat (2000) @(negedge clk); end
        edges = 0; repeat (5000) @(negedge clk);
        expect_eq("jump sound ends", edges, 0);
        state = 0;

        // ---- LCD: 초기화, 평소 문구, 떨어짐, 클리어 ----
        repeat (200000) @(negedge clk);
        expect_eq("lcd: function set sent 3 times", n_func, 3);
        expect_eq("lcd: display on", display_on, 1);
        expect_eq("lcd: custom char 1 row 4 (grin)", cgram[8 + 4], 8'b11111);
        expect_eq("lcd: custom char 2 row 1 (open mouth)", cgram[16 + 1], 8'b11111);
        expect_lines("  CHARGE  JUMP  ", "    STAGE 1     ");
        screen = 2; repeat (150000) @(negedge clk);
        expect_lines("  CHARGE  JUMP  ", "    STAGE 3     ");
        // 스테이지 3 → 2 로 떨어짐
        screen = 1; @(negedge clk) fell = 1; @(negedge clk) fell = 0;
        repeat (150000) @(negedge clk);
        expect_lines("# m9(^$^) LOL! #", " FELL TO STAGE 2");
        repeat (30) do_tick;                                           // TAUNT_FRAMES 가 지나면 평소 문구로
        repeat (150000) @(negedge clk);
        expect_lines("  CHARGE  JUMP  ", "    STAGE 2     ");
        cleared = 1; repeat (150000) @(negedge clk);
        expect_lines("**** CLEAR! ****", "   GOOD JOB! #  ");
        // 확장 기능 끔: 떨어져도 평소 문구
        cleared = 0; plain = 1; @(negedge clk) fell = 1; @(negedge clk) fell = 0;
        repeat (150000) @(negedge clk);
        expect_lines("  CHARGE  JUMP  ", "    STAGE 2     ");
        expect_eq("lcd: E pulse at least 2us", e_high_errors, 0);
        expect_eq("lcd: RW stays low", lcd_rw, 0);

        if (errors == 0) $display("PASS (%0d checks)", checks); else $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule
