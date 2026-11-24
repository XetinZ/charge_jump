#!/usr/bin/env python3
"""sin 표(sin.mem) 생성 + 테일러 급수 오차 비교 (보고서용).

사용:  python tools/make_trig.py                 # rtl/sin.mem 생성, 오차 표 출력
       python tools/make_trig.py --plot err.png  # 오차 그래프 저장 (matplotlib 필요)
       python tools/make_trig.py --rtl sim/trig_taylor_out.txt   # tb_trig 출력과 비교
"""
import argparse
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FRAC = 12
ONE = 1 << FRAC


def write_table(path: Path):
    vals = [round(math.sin(math.radians(a)) * ONE) for a in range(91)]
    path.write_text("".join(f"{v:04x}\n" for v in vals), encoding="ascii")
    return vals


def taylor(angle, terms, fold45):
    """부동소수 테일러 근사. fold45: 0~45도로 접어서 계산."""
    a = 180 - angle if angle > 90 else angle
    neg = angle > 90
    swap = fold45 and a > 45
    x = math.radians(90 - a if swap else a)
    x2 = x * x
    if terms == 2:
        s, c = x * (1 - x2 / 6), 1 - x2 / 2
    else:
        s, c = x * (1 - x2 / 6 * (1 - x2 / 20)), 1 - x2 / 2 * (1 - x2 / 12)
    if swap:
        s, c = c, s
    return s, (-c if neg else c)


def err_lsb(angle, s, c):
    return ((s - math.sin(math.radians(angle))) * ONE,
            (c - math.cos(math.radians(angle))) * ONE)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument("--mem", default=str(ROOT / "rtl" / "sin.mem"))
    ap.add_argument("--plot", help="오차 그래프 PNG 경로")
    ap.add_argument("--rtl", help="tb_trig 가 쓴 'angle sin cos' 텍스트 파일")
    a = ap.parse_args()

    write_table(Path(a.mem))
    print(f"{a.mem} 생성 (91개, 소수 {FRAC}비트)")

    cases = [(2, False), (3, False), (2, True), (3, True)]
    curves = {}
    print("\n테일러 근사 최대 오차 (LSB = 1/4096, 0~180도)")
    print(" 항 수  계산 범위   sin 최대   cos 최대   cos(90)")
    for terms, fold in cases:
        errs = [err_lsb(d, *taylor(d, terms, fold)) for d in range(181)]
        curves[(terms, fold)] = errs
        ms = max(abs(e[0]) for e in errs)
        mc = max(abs(e[1]) for e in errs)
        print(f"  {terms}     {'0~45' if fold else '0~90'}      {ms:8.2f}   {mc:8.2f}   {errs[90][1]:7.2f}")

    rtl = None
    if a.rtl:
        rtl = []
        for line in Path(a.rtl).read_text().split("\n"):
            if line.strip():
                d, s, c = map(int, line.split())
                rtl.append((s - math.sin(math.radians(d)) * ONE, c - math.cos(math.radians(d)) * ONE))
        print(f"\nRTL(trig_taylor) 최대 오차: sin {max(abs(e[0]) for e in rtl):.2f} LSB, "
              f"cos {max(abs(e[1]) for e in rtl):.2f} LSB, cos(90) = {rtl[90][1]:.2f}")

    if a.plot:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        fig, ax = plt.subplots(2, 1, figsize=(9, 7), sharex=True)
        for (terms, fold), errs in curves.items():
            label = f"{terms} terms, {'0-45' if fold else '0-90'} deg"
            ax[0].plot([e[0] for e in errs], label=label)
            ax[1].plot([e[1] for e in errs], label=label)
        if rtl:
            ax[0].plot([e[0] for e in rtl], "k.", ms=3, label="RTL (fixed point)")
            ax[1].plot([e[1] for e in rtl], "k.", ms=3, label="RTL (fixed point)")
        for x, name in zip(ax, ("sin", "cos")):
            x.set_ylabel(f"{name} error (LSB)")
            x.set_yscale("symlog", linthresh=4)
            x.grid(True, alpha=0.3)
            x.legend(fontsize=8)
        ax[1].set_xlabel("angle (deg)")
        fig.tight_layout()
        fig.savefig(a.plot, dpi=130)
        print(f"{a.plot} 저장")


if __name__ == "__main__":
    main()
