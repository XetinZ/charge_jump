r"""UART 핀 확인용: PC 에서 보드 쪽으로 0x55 를 계속 보낸다.

보드에서 DIP_SW4 를 올린 상태(확인 모드)로 실행한다. USB 칩의 출력이 연결된 핀의 LED 가 깜빡인다.
    LED1 깜빡임 → 칩 출력 = F6  → FPGA 는 C6 으로 보내야 한다 (DIP_SW3 올림)
    LED2 깜빡임 → 칩 출력 = C6  → FPGA 는 F6 으로 보내야 한다 (DIP_SW3 내림)
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
        print(f"{a.port} 로 0x55 를 {a.seconds:.0f}초 동안 보냅니다. 보드의 LED1/LED2 를 보세요. (Ctrl+C 로 중단)")
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
