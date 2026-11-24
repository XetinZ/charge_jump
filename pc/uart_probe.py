r"""UART 핀 확인용: PC 에서 보드 쪽으로 0x55 를 계속 보낸다.

보드에서 DIP_SW4 를 올린 상태(확인 모드)로 실행한다. PC 신호가 들어오는 핀의 LED 가 켜진다.
    9핀 시리얼 단자 (DIP_SW5 내림)
        LED1 켜짐 → A3 가 PC → FPGA 방향 → FPGA 는 A5 로 보낸다 (DIP_SW3 올림)
        LED2 켜짐 → A5 가 PC → FPGA 방향 → FPGA 는 A3 로 보낸다 (DIP_SW3 내림)
    USB 시리얼 (DIP_SW5 올림)
        LED3 켜짐 → F6 이 PC → FPGA 방향 → FPGA 는 C6 으로 보낸다 (DIP_SW3 올림)
        LED4 켜짐 → C6 이 PC → FPGA 방향 → FPGA 는 F6 으로 보낸다 (DIP_SW3 내림)
뷰어와 같은 포트를 쓰므로 뷰어는 끄고 실행한다.

사용:  py pc\uart_probe.py COM5
필요:  pip install pyserial
"""
import argparse
import time


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument("port")
    ap.add_argument("--baud", type=int, default=19200)
    ap.add_argument("--seconds", type=float, default=30)
    a = ap.parse_args()

    import serial
    with serial.Serial(a.port, a.baud, timeout=0) as ser:
        print(f"{a.port} 로 0x55 를 {a.seconds:.0f}초 동안 보냅니다. 보드의 LED1~4 를 보세요. (Ctrl+C 로 중단)")
        end = time.time() + a.seconds
        got = 0
        try:
            while time.time() < end:
                ser.write(b"\x55" * 64)
                got += len(ser.read(ser.in_waiting or 1))
                time.sleep(0.02)
        except KeyboardInterrupt:
            pass
        print(f"끝. 그동안 보드에서 받은 바이트: {got}")


if __name__ == "__main__":
    main()
