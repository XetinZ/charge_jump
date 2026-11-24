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
set_property -dict {PACKAGE_PIN U2 IOSTANDARD LVCMOS33} [get_ports dip_uart_sel] ;# DIP_SW3: UART 송신 핀 0 F6 / 1 C6
set_property -dict {PACKAGE_PIN T1 IOSTANDARD LVCMOS33} [get_ports dip_probe]    ;# DIP_SW4: 1 UART 핀 확인 모드

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

## ---- UART: USB to Serial 의 두 핀 ----
## 핀맵 이름(USB_TXD0 / USB_RXD0)이 FPGA 기준인지 USB 칩 기준인지 확인되지 않아 두 핀을 다 잡고,
## DIP_SW3 으로 송신 핀을 고른다. 고르지 않은 핀은 입력(High-Z)이다. DIP_SW4 를 올리면 둘 다 입력이 되고
## LED 로 어느 핀에 PC 신호가 들어오는지 보여준다 (pc/uart_probe.py). 별도 UART 커넥터는 UART_TXD1 = A3.
## 풀업: 입력으로 둔 핀이 떠서 잡음으로 깜빡이지 않게 한다 (칩 출력이 연결된 쪽은 칩이 이긴다)
set_property -dict {PACKAGE_PIN F6 IOSTANDARD LVCMOS33 PULLUP true} [get_ports uart_f6]     ;# USB_TXD0
set_property -dict {PACKAGE_PIN C6 IOSTANDARD LVCMOS33 PULLUP true} [get_ports uart_c6]     ;# USB_RXD0

## 버튼·스위치는 비동기 입력이므로 타이밍 분석에서 제외
set_false_path -from [get_ports {btn_* dip_*}]
