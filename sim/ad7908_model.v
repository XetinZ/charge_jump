`timescale 1ns/1ps
// ad7908_model.v — 테스트벤치용 AD7908 동작 모델 (데이터시트 기준, 타이밍 검사는 일부만).
//   - CS 하강: 지난 변환 결과 프레임을 내보내기 시작 (첫 비트 0)
//   - SCLK 하강 에지마다 DIN 을 읽고 DOUT 을 다음 비트로
//   - 앞 12비트의 WRITE 가 1 이면 제어 레지스터 갱신. ADD 는 "다음" 변환 채널
//   - 전원 인가 뒤 DIN 이 모두 1 인 프레임을 2개 받기 전에는 결과를 0xEE 로 내보낸다
module ad7908_model (
    input  wire       cs,
    input  wire       sclk,
    input  wire       din,
    output wire       dout,
    input  wire [7:0] vin0, vin1, vin2, vin3, vin4, vin5, vin6, vin7
);
    reg [15:0] out_sh;
    reg [11:0] in_sh;
    reg [4:0]  n;
    reg [2:0]  conv_ch = 3'd0;         // 이번 프레임에서 변환하는 채널
    reg [2:0]  add_reg = 3'd0;
    reg [1:0]  ones_frames = 0;
    reg        out_en = 0;
    integer    frames = 0, bad_ctrl = 0, cs_while_sclk_low = 0;

    function [7:0] vin_of; input [2:0] c;
        case (c) 0: vin_of = vin0; 1: vin_of = vin1; 2: vin_of = vin2; 3: vin_of = vin3;
                 4: vin_of = vin4; 5: vin_of = vin5; 6: vin_of = vin6; default: vin_of = vin7; endcase
    endfunction

    assign dout = out_en ? out_sh[15] : 1'bz;

    always @(negedge cs) begin
        if (!sclk) cs_while_sclk_low = cs_while_sclk_low + 1;
        out_sh = {1'b0, conv_ch, (ones_frames == 2) ? vin_of(conv_ch) : 8'hEE, 4'b0000};
        out_en = 1;
        n = 0;
    end
    always @(negedge sclk) if (!cs) begin
        if (n < 12) in_sh = {in_sh[10:0], din};
        n = n + 1;
        out_sh = {out_sh[14:0], 1'b0};
        if (n == 16) out_en = 0;
    end
    always @(posedge cs) begin
        frames = frames + 1;
        if (n == 16) begin
            if (in_sh == 12'hFFF && ones_frames != 2) ones_frames = ones_frames + 1;
            else if (in_sh[11]) begin
                // 이 프로젝트가 쓰는 값: SEQ=0, PM=11, SHADOW=0, RANGE=1, CODING=1
                if (in_sh[10] !== 1'b0 || in_sh[5:4] !== 2'b11 || in_sh[3] !== 1'b0 || in_sh[1:0] !== 2'b11)
                    bad_ctrl = bad_ctrl + 1;
                add_reg = in_sh[8:6];
            end
        end
        conv_ch = add_reg;             // 다음 프레임은 방금 쓴 채널을 변환
    end
endmodule
