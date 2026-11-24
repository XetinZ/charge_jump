# FPGA 차지 점프 게임

명세서: https://claude.ai/artifact/5NGWAgDqcSHVsHEJNqfMVC

## 폴더

| 경로 | 내용 |
|---|---|
| `rtl/` | 합성 대상 Verilog, `params.vh`, `map.mem`, `sin.mem` |
| `sim/` | 테스트벤치 (`tb_*.v`), 공통부 `tb_harness.vh`, 시험용 맵 |
| `constrs/` | 핀 제약 (Xilinx_S7_Pin_Map.xlsx 기준) |
| `maps/` | 맵 원본 `screenN.txt` (40자 x 30줄, `.` `#` `G` `S`) |
| `tools/` | `make_map.py`, `make_trig.py` |
| `pc/` | `viewer.py`, `map.json` |

## Vivado 에 등록

프로젝트를 열고 Tcl 콘솔에서 `source C:/Users/sun20/vivado/charge_jump/add_sources.tcl`

## 보드에 올리기 전에 정할 것 (명세 10장)

실습 자료(2·7·10주차)로 확정한 것: 클록 핀 B6, 버튼 누르면 High, LED High 면 켜짐, 딥 스위치 올리면 High,
서보 핀 AA22와 펄스 폭 0.7ms(0도) / 1.5ms(90도) / 2.3ms(180도).

보드에서 할 일:
1. **CLOCK SELECT 를 1MHz 로** 맞춘다 (`params.vh` 의 `CLK_HZ = 1_000_000`). 다른 값을 쓰면 `CLK_HZ` 와 XDC 의 클록 주기를 같이 고친다.
2. **SWA 스위치를 OFF(PUSH SWITCH)** 로 둔다 (버튼을 하나씩 직접 읽기 때문. 추정이므로 버튼이 안 먹으면 ON 으로 바꿔 본다).
3. 뷰어는 **19200bps** 로 연다. 1MHz 에서 115200bps 는 분주 오차가 3.5% 라 쓸 수 없다.
4. UART 송신 핀: 실습 자료에 방향이 없어서 9핀 시리얼 단자(A3, A5)와 USB 시리얼(F6, C6) 네 핀을 모두 잡아 두었다.
   DIP_SW5 로 단자(내림 9핀 시리얼 / 올림 USB), DIP_SW3 으로 그 단자의 핀(내림 TXD 이름 핀 / 올림 RXD 이름 핀)을 고른다. 기본은 A3.
   방향을 모르면 DIP_SW4 를 올리고(네 핀 모두 입력, 아무것도 구동하지 않음) `py pc\uart_probe.py COM5` 를 실행한다.
   PC 신호가 들어오는 핀의 LED(LED1~4 = A3, A5, F6, C6)가 켜진다. FPGA 는 같은 단자의 다른 핀으로 보내야 하므로
   LED1 이면 DIP_SW3 올림, LED2 면 내림 (USB 는 LED3 이면 올림, LED4 면 내림). 끝나면 DIP_SW4 를 내린다.
5. 서보가 끝까지 안 돌거나 떨면 `params.vh` 의 `SERVO_MIN_US`, `SERVO_SLOPE` 를 조금씩 조정한다 (7주차 자료도 보드마다 다르다고 함).

딥 스위치: 1번 `dip_trig` 0 = ROM 표 / 1 = 테일러, 2번 `dip_test` 1 = 고정 패킷 송신 (x 320, y 240, 차지 32, 각도 45),
3번 `dip_uart_sel` 단자 안의 송신 핀 0 = TXD 이름 핀 / 1 = RXD 이름 핀, 4번 `dip_probe` 1 = UART 핀 확인 모드 (LED 로 표시),
5번 `dip_uart_port` 단자 0 = 9핀 시리얼(A3, A5) / 1 = USB 시리얼(F6, C6), 6번 `dip_ext_off` 1 = 확장 기능 끔,
7번 `dip_cal` 1 = CDS 보정 표시.

## 확장 기능

| 장치 | 동작 |
|---|---|
| 1자리 7-세그먼트 | 스테이지 번호 (화면 번호 + 1) |
| 8자리 7-세그먼트 | 경과 시간, 0.01초 단위. 첫 차지부터 세고 클리어에서 멈춘다. 리셋 버튼으로 0 |
| 텍스트 LCD | 평소 `CHARGE JUMP / STAGE n`. 아래 스테이지로 떨어지면 3초 동안 `m9(^▽^) LOL! / FELL TO STAGE n`, 클리어하면 `CLEAR!` |
| 피에조 | 차지 중 점점 높아지는 음, 점프 순간 짧게 올라가는 음. 보드의 PIEZO ENABLE 스위치가 ON 이어야 한다 |
| 서보 | 방향을 반대로 (`params.vh` 의 `SERVO_REVERSE`) |
| 각도 버튼 | 누르고 있을 때 4프레임에 5도 (초당 75도, 이전의 1.25배) |
| CDS 조도 센서 | 우주 스테이지(3번)에서 센서에 빛을 비출수록 캐릭터 주변이 넓게 보인다. FPGA 가 밝기를 어둠 단계 0~3 으로 정해 패킷 상태 바이트 7:6 으로 보내고, 뷰어는 그만큼 화면을 덮는다 |

### CDS 보정 (보드에서 한 번)

ADC(AD7908)는 8채널인데 CDS 가 몇 번 채널인지 자료에 없다. DIP_SW7 을 올리면 8자리 7-세그먼트에
`[채널]  [단계] [값]` 이 나오고 채널이 1.5초마다 0~7 을 돈다.
1. CDS 센서를 손으로 가렸다가 휴대폰 손전등을 비춰 본다. 값이 크게 바뀌는 채널 번호를 `params.vh` 의 `LIGHT_CH` 에 적는다.
2. 밝을수록 값이 작아지면 `LIGHT_INV` 를 1 로 한다.
3. 실내 조명에서 어둡게(단계 0~1), 손전등을 비추면 밝게(3) 나오도록 `LIGHT_T1~T3` 을 맞춘다.
4. 모든 채널이 0 이나 255 로만 나오면 XDC 에서 `adc_din`(H5) 과 `adc_dout`(J6) 핀을 서로 바꿔 본다.

DIP_SW6 을 올리면 피에조·7-세그먼트가 꺼지고 LCD 는 평소 문구만 낸다 (기본 모드 시연용).
보드에서 확인할 것: 8자리 숫자가 좌우로 뒤집혀 나오면 `params.vh` 의 `SEG_S0_IS_LEFT` 를 0 으로.
텍스트 LCD 는 실습 자료가 없어 HD44780 8비트 방식으로 가정했다.

## 맵을 고쳤을 때

```
py tools\make_map.py          # rtl/map.mem, pc/map.json, params.vh 의 시작 위치 갱신
```
맵이나 물리 상수를 바꾸면 `sim/tb_play.v` 의 점프 경로도 다시 잡아야 한다.

## 시뮬레이션

| 테스트벤치 | 확인하는 것 |
|---|---|
| `tb_trig` | ROM·테일러 0~180도 오차 (3 LSB 이하, cos 90 = 0) |
| `tb_packet` | 11바이트 패킷 내용, 체크섬, 전송 중 값 변경 |
| `tb_periph` | 버튼 떨림 제거, LED 게이지, 서보 펄스 폭, 틱 주기 |
| `tb_ext` | 확장 기능: 8자리 시간 표시와 보정 표시, 피에조 음 높이, LCD 초기화와 문구, AD7908 읽기와 어둠 단계 (`ad7908_model.v`) |
| `tb_physics` | 각도 버튼, 차지, 평지 점프의 최고 높이·착지 프레임 (손 계산값) |
| `tb_collision` | 벽·천장·모서리·1칸 틈·무작위 점프 400회, 화면 전환, 클리어 |
| `tb_play` | 실제 맵을 시작부터 클리어까지 3회 연속 |
| `tb_top` | 버튼 핀 → UART 핀 전체 경로 (보드와 같은 1MHz, 19200bps) |

Vivado: 시뮬레이션 top 을 바꿔 가며 Run Simulation, 또는 `sim\run_xsim.bat tb_physics`.
Icarus Verilog: `sim/run_iverilog.sh`.

테일러 오차 그래프: `tb_trig` 가 쓴 `trig_taylor_out.txt` 로
`py tools\make_trig.py --rtl <경로>/trig_taylor_out.txt --plot err.png`

## 그림 (에셋)

ChatGPT 로 만든 원본은 `pc\assets\src` 에 둔다 (`sprites.png`, `tiles.png`, `bg_forest.png`, `bg_sky.png`, `bg_space.png`).
`py -m pip install pillow numpy` 후 `py tools\make_assets.py` 를 실행하면 뷰어용 그림(배경 640x480, 타일 16x16,
캐릭터 24x24 여섯 동작)과 확인용 `preview.png` 가 `pc\assets` 에 생긴다. 그림이 없으면 뷰어는 도형으로 그린다.
캐릭터 동작은 FPGA 가 보낸 비트로만 고른다: 차지(상태 1), 상승/낙하(공중 + 패킷 6번 바이트 비트 3), 착지(착지 비트 후 8프레임), 승리(클리어).

## 뷰어

```
py -m pip install pygame pyserial
py pc\viewer.py COM3 [--baud 19200] [--csv log.csv] [--scale 2]
```

## 명세에 없어서 구현하면서 정한 것

- 충돌 판정은 좌표의 픽셀 정수부로 한다 (상자 = `[px, px+15] x [py, py+15]`).
- `vx = (speed x cos) >> 12` 는 산술 시프트라 같은 차지에서 왼쪽이 1/16 px/프레임 빠르다 (45도 134, 135도 -135).
- 리셋 버튼은 클리어뿐 아니라 모든 상태에서 시작 위치로 돌려보낸다.
- 목표 타일에 닿으면 그 자리(공중일 수 있음)에서 멈춘다. 착지 프레임에도 목표를 확인한다.
- 점프하는 순간 `charge` 를 0 으로 되돌린다.
- 타일 값 `11`(예약)은 빈 공간으로 취급한다.
- 전원 인가 리셋은 `top.v` 안의 카운터로 만든다 (외부 리셋 핀 없음).
- 이산 계산이라 최대 수직 점프는 135px, 45도 비거리는 276px 다 (명세의 141px, 282px 는 연속 근사).
