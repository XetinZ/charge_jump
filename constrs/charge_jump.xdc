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

## 버튼·스위치는 비동기 입력이므로 타이밍 분석에서 제외
set_false_path -from [get_ports {btn_* dip_*}]
