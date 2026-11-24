## charge_jump.xdc — HBE-Combo II-DLD (xc7s75fgga484-1) 핀 제약
## 핀 번호 출처: Xilinx_S7_Pin_Map.xlsx (DLD-Spartan7-Peripheral 시트)
## 버튼·LED·딥 스위치의 논리 레벨은 top.v 의 BTN_ACTIVE_LOW / LED_ACTIVE_LOW / DIP_ACTIVE_LOW 로 맞춘다.

## ---- 클록: FPGA_CLK1 (실습 자료의 clk 핀과 같음) ----
## 보드의 CLOCK SELECT 로 주파수를 고른다. 1MHz 로 맞출 것 (params.vh 의 CLK_HZ = 1_000_000).
## 주파수를 바꾸면 CLK_HZ 와 아래 주기를 함께 고친다.
set_property -dict {PACKAGE_PIN B6 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -name sys_clk -period 1000.000 [get_ports clk]

## ---- 버튼: 누르면 High (2주차 자료). 키패드 윗줄 1 2 3 = 왼쪽 차지 오른쪽, 4 = 리셋 ----
## 2주차 자료에서 키패드 1, 2, 3 이 K4, N8, N4 였다. KEY04 = 4 는 순서로 추정.
set_property -dict {PACKAGE_PIN K4 IOSTANDARD LVCMOS33} [get_ports btn_left]    ;# KEY01 (키패드 1)
set_property -dict {PACKAGE_PIN N8 IOSTANDARD LVCMOS33} [get_ports btn_charge]  ;# KEY02 (키패드 2)
set_property -dict {PACKAGE_PIN N4 IOSTANDARD LVCMOS33} [get_ports btn_right]   ;# KEY03 (키패드 3)
set_property -dict {PACKAGE_PIN N1 IOSTANDARD LVCMOS33} [get_ports btn_reset]   ;# KEY04 (키패드 4)

## ---- 딥 스위치: 위로 올리면 High (2주차 자료) ----
set_property -dict {PACKAGE_PIN Y1 IOSTANDARD LVCMOS33} [get_ports dip_trig]    ;# DIP_SW1: 0 ROM / 1 테일러
set_property -dict {PACKAGE_PIN W3 IOSTANDARD LVCMOS33} [get_ports dip_test]    ;# DIP_SW2: 1 고정 패킷
set_property -dict {PACKAGE_PIN U2 IOSTANDARD LVCMOS33} [get_ports dip_uart_sel]  ;# DIP_SW3: 단자 안의 핀 0 TXD쪽 / 1 RXD쪽
set_property -dict {PACKAGE_PIN T1 IOSTANDARD LVCMOS33} [get_ports dip_probe]     ;# DIP_SW4: 1 UART 핀 확인 모드
set_property -dict {PACKAGE_PIN W4 IOSTANDARD LVCMOS33} [get_ports dip_uart_port] ;# DIP_SW5: 단자 0 9핀 시리얼 / 1 USB
set_property -dict {PACKAGE_PIN W1 IOSTANDARD LVCMOS33} [get_ports dip_ext_off]   ;# DIP_SW6: 1 확장 기능 끔

## ---- LED 8개: High 면 켜짐 (2주차 자료). led[0] = LED1 이 게이지의 첫 칸 ----
set_property -dict {PACKAGE_PIN L4 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN M4 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN M2 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN N7 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN M7 IOSTANDARD LVCMOS33} [get_ports {led[4]}]
set_property -dict {PACKAGE_PIN M3 IOSTANDARD LVCMOS33} [get_ports {led[5]}]
set_property -dict {PACKAGE_PIN M1 IOSTANDARD LVCMOS33} [get_ports {led[6]}]
set_property -dict {PACKAGE_PIN N5 IOSTANDARD LVCMOS33} [get_ports {led[7]}]

## ---- 서보 PWM: SERVO_CTRL (7주차 자료와 같음) ----
set_property -dict {PACKAGE_PIN AA22 IOSTANDARD LVCMOS33} [get_ports servo]

## ---- UART: 9핀 시리얼 단자(A3, A5)와 USB 시리얼(F6, C6) ----
## 핀맵 이름(TXD/RXD)이 FPGA 기준인지 칩 기준인지 확인되지 않아 네 핀을 다 잡고 딥 스위치로 송신 핀을 고른다.
## DIP_SW5 = 단자 (0 9핀 시리얼, 1 USB), DIP_SW3 = 그 단자의 핀 (0 TXD 이름 핀, 1 RXD 이름 핀). 기본은 A3.
## 고르지 않은 핀은 입력(High-Z). DIP_SW4 를 올리면 넷 다 입력이 되고 LED 로 PC 신호가 들어오는 핀을 보여준다.
## 풀업: 입력으로 둔 핀이 떠서 잡음으로 깜빡이지 않게 한다 (칩 출력이 연결된 쪽은 칩이 이긴다)
set_property -dict {PACKAGE_PIN A3 IOSTANDARD LVCMOS33 PULLUP true} [get_ports uart_a3]     ;# UART_TXD1
set_property -dict {PACKAGE_PIN A5 IOSTANDARD LVCMOS33 PULLUP true} [get_ports uart_a5]     ;# UART_RXD1
set_property -dict {PACKAGE_PIN F6 IOSTANDARD LVCMOS33 PULLUP true} [get_ports uart_f6]     ;# USB_TXD0
set_property -dict {PACKAGE_PIN C6 IOSTANDARD LVCMOS33 PULLUP true} [get_ports uart_c6]     ;# USB_RXD0

## ---- 확장: 1자리 7-세그먼트 (스테이지 번호). seg = {a,b,c,d,e,f,g,dp}, 1 이면 켜짐 (4주차 자료) ----
set_property -dict {PACKAGE_PIN P1 IOSTANDARD LVCMOS33} [get_ports {seg[7]}]  ;# SEG_A
set_property -dict {PACKAGE_PIN P3 IOSTANDARD LVCMOS33} [get_ports {seg[6]}]  ;# SEG_B
set_property -dict {PACKAGE_PIN P7 IOSTANDARD LVCMOS33} [get_ports {seg[5]}]  ;# SEG_C
set_property -dict {PACKAGE_PIN N3 IOSTANDARD LVCMOS33} [get_ports {seg[4]}]  ;# SEG_D
set_property -dict {PACKAGE_PIN T5 IOSTANDARD LVCMOS33} [get_ports {seg[3]}]  ;# SEG_E
set_property -dict {PACKAGE_PIN R2 IOSTANDARD LVCMOS33} [get_ports {seg[2]}]  ;# SEG_F
set_property -dict {PACKAGE_PIN R4 IOSTANDARD LVCMOS33} [get_ports {seg[1]}]  ;# SEG_G
set_property -dict {PACKAGE_PIN R6 IOSTANDARD LVCMOS33} [get_ports {seg[0]}]  ;# SEG_DP

## ---- 확장: 8자리 7-세그먼트 (경과 시간). 데이터는 1 이면 켜짐, 자리 선택은 0 이면 선택 (4주차 자료) ----
## 숫자가 좌우로 뒤집혀 나오면 params.vh 의 SEG_S0_IS_LEFT 를 0 으로 바꾼다.
set_property -dict {PACKAGE_PIN F1 IOSTANDARD LVCMOS33} [get_ports {ar_seg[7]}]  ;# AR_SEG_A
set_property -dict {PACKAGE_PIN F5 IOSTANDARD LVCMOS33} [get_ports {ar_seg[6]}]  ;# AR_SEG_B
set_property -dict {PACKAGE_PIN E2 IOSTANDARD LVCMOS33} [get_ports {ar_seg[5]}]  ;# AR_SEG_C
set_property -dict {PACKAGE_PIN E4 IOSTANDARD LVCMOS33} [get_ports {ar_seg[4]}]  ;# AR_SEG_D
set_property -dict {PACKAGE_PIN J1 IOSTANDARD LVCMOS33} [get_ports {ar_seg[3]}]  ;# AR_SEG_E
set_property -dict {PACKAGE_PIN J3 IOSTANDARD LVCMOS33} [get_ports {ar_seg[2]}]  ;# AR_SEG_F
set_property -dict {PACKAGE_PIN J7 IOSTANDARD LVCMOS33} [get_ports {ar_seg[1]}]  ;# AR_SEG_G
set_property -dict {PACKAGE_PIN H2 IOSTANDARD LVCMOS33} [get_ports {ar_seg[0]}]  ;# AR_SEG_DP
set_property -dict {PACKAGE_PIN H4 IOSTANDARD LVCMOS33} [get_ports {ar_sel[0]}]  ;# AR_SEG_S0
set_property -dict {PACKAGE_PIN H6 IOSTANDARD LVCMOS33} [get_ports {ar_sel[1]}]  ;# AR_SEG_S1
set_property -dict {PACKAGE_PIN G1 IOSTANDARD LVCMOS33} [get_ports {ar_sel[2]}]  ;# AR_SEG_S2
set_property -dict {PACKAGE_PIN G3 IOSTANDARD LVCMOS33} [get_ports {ar_sel[3]}]  ;# AR_SEG_S3
set_property -dict {PACKAGE_PIN L6 IOSTANDARD LVCMOS33} [get_ports {ar_sel[4]}]  ;# AR_SEG_S4
set_property -dict {PACKAGE_PIN K1 IOSTANDARD LVCMOS33} [get_ports {ar_sel[5]}]  ;# AR_SEG_S5
set_property -dict {PACKAGE_PIN K3 IOSTANDARD LVCMOS33} [get_ports {ar_sel[6]}]  ;# AR_SEG_S6
set_property -dict {PACKAGE_PIN K5 IOSTANDARD LVCMOS33} [get_ports {ar_sel[7]}]  ;# AR_SEG_S7

## ---- 확장: 16x2 텍스트 LCD (HD44780 8비트로 가정. 실습 자료에 없음) ----
set_property -dict {PACKAGE_PIN A4 IOSTANDARD LVCMOS33} [get_ports {lcd_d[0]}]  ;# TLCD_D0
set_property -dict {PACKAGE_PIN B2 IOSTANDARD LVCMOS33} [get_ports {lcd_d[1]}]  ;# TLCD_D1
set_property -dict {PACKAGE_PIN C3 IOSTANDARD LVCMOS33} [get_ports {lcd_d[2]}]  ;# TLCD_D2
set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS33} [get_ports {lcd_d[3]}]  ;# TLCD_D3
set_property -dict {PACKAGE_PIN A2 IOSTANDARD LVCMOS33} [get_ports {lcd_d[4]}]  ;# TLCD_D4
set_property -dict {PACKAGE_PIN C5 IOSTANDARD LVCMOS33} [get_ports {lcd_d[5]}]  ;# TLCD_D5
set_property -dict {PACKAGE_PIN C1 IOSTANDARD LVCMOS33} [get_ports {lcd_d[6]}]  ;# TLCD_D6
set_property -dict {PACKAGE_PIN D1 IOSTANDARD LVCMOS33} [get_ports {lcd_d[7]}]  ;# TLCD_D7
set_property -dict {PACKAGE_PIN A6 IOSTANDARD LVCMOS33} [get_ports lcd_e]   ;# TLCD_E
set_property -dict {PACKAGE_PIN G6 IOSTANDARD LVCMOS33} [get_ports lcd_rs]  ;# TLCD_RS
set_property -dict {PACKAGE_PIN D6 IOSTANDARD LVCMOS33} [get_ports lcd_rw]  ;# TLCD_RW

## ---- 확장: 피에조 (보드의 PIEZO ENABLE 스위치가 ON 이어야 소리가 난다) ----
set_property -dict {PACKAGE_PIN Y21 IOSTANDARD LVCMOS33} [get_ports piezo]

## 버튼·스위치는 비동기 입력이므로 타이밍 분석에서 제외
set_false_path -from [get_ports {btn_* dip_*}]
