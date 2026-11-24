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
4. UART 송신 핀: 실습 자료에도 없어서 F6, C6 을 모두 잡아 두었다. DIP_SW3 내림 = F6, 올림 = C6 으로 보낸다.
   어느 쪽인지 모르면 DIP_SW4 를 올리고(두 핀 모두 입력, 아무것도 구동하지 않음) `py pc\uart_probe.py COM5` 를 실행한다.
   LED1 이 깜빡이면 F6 이 칩 출력이니 DIP_SW3 을 올리고, LED2 가 깜빡이면 DIP_SW3 을 내린다. 끝나면 DIP_SW4 를 내린다.
5. 서보가 끝까지 안 돌거나 떨면 `params.vh` 의 `SERVO_MIN_US`, `SERVO_SLOPE` 를 조금씩 조정한다 (7주차 자료도 보드마다 다르다고 함).

딥 스위치: 1번 `dip_trig` 0 = ROM 표 / 1 = 테일러, 2번 `dip_test` 1 = 고정 패킷 송신 (x 320, y 240, 차지 32, 각도 45),
3번 `dip_uart_sel` UART 송신 핀 0 = F6 / 1 = C6, 4번 `dip_probe` 1 = UART 핀 확인 모드 (LED 로 표시).

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
| `tb_physics` | 각도 버튼, 차지, 평지 점프의 최고 높이·착지 프레임 (손 계산값) |
| `tb_collision` | 벽·천장·모서리·1칸 틈·무작위 점프 400회, 화면 전환, 클리어 |
| `tb_play` | 실제 맵을 시작부터 클리어까지 3회 연속 |
| `tb_top` | 버튼 핀 → UART 핀 전체 경로 (보드와 같은 1MHz, 19200bps) |

Vivado: 시뮬레이션 top 을 바꿔 가며 Run Simulation, 또는 `sim\run_xsim.bat tb_physics`.
Icarus Verilog: `sim/run_iverilog.sh`.

테일러 오차 그래프: `tb_trig` 가 쓴 `trig_taylor_out.txt` 로
`py tools\make_trig.py --rtl <경로>/trig_taylor_out.txt --plot err.png`

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
