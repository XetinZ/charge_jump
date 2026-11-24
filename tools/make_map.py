"""맵 원본(maps/screenN.txt) -> map.mem(FPGA) + map.json(뷰어) + params.vh 시작 위치.

사용:  python tools/make_map.py
       python tools/make_map.py --maps sim/maps_test --mem sim/test_map.mem --json - --params -
출력 경로에 '-' 를 주면 그 파일은 만들지 않는다.
"""
import argparse
import json
import re
import sys
from pathlib import Path

COLS, ROWS, TILE, MAX_SCREENS = 40, 30, 16, 8
CODE = {".": 0, "#": 1, "G": 2, "S": 0}
ROOT = Path(__file__).resolve().parent.parent


def load(maps_dir: Path):
    files = sorted(maps_dir.glob("screen*.txt"),
                   key=lambda p: int(re.search(r"(\d+)", p.stem).group(1)))
    if not files:
        sys.exit(f"오류: {maps_dir} 에 screenN.txt 가 없습니다")
    if len(files) > MAX_SCREENS:
        sys.exit(f"오류: 화면은 최대 {MAX_SCREENS}개입니다")
    screens = []
    for i, f in enumerate(files):
        if f.stem != f"screen{i}":
            sys.exit(f"오류: 화면 번호가 0부터 연속이어야 합니다 ({f.name})")
        rows = f.read_text(encoding="utf-8").splitlines()
        if len(rows) != ROWS:
            sys.exit(f"오류: {f.name} 은 {len(rows)}줄입니다 ({ROWS}줄이어야 함)")
        for n, r in enumerate(rows):
            if len(r) != COLS:
                sys.exit(f"오류: {f.name} {n + 1}번째 줄 길이 {len(r)} ({COLS}이어야 함)")
            bad = set(r) - set(CODE)
            if bad:
                sys.exit(f"오류: {f.name} {n + 1}번째 줄에 모르는 문자 {sorted(bad)}")
        screens.append(rows)
    return screens


def find(screens, ch):
    return [(s, ty, tx) for s, rows in enumerate(screens)
            for ty, r in enumerate(rows) for tx, c in enumerate(r) if c == ch]


def check(screens):
    starts, goals = find(screens, "S"), find(screens, "G")
    if len(starts) != 1:
        sys.exit(f"오류: S 는 한 번만 나와야 합니다 (현재 {len(starts)}번)")
    if len(goals) != 1:
        sys.exit(f"오류: G 는 한 번만 나와야 합니다 (현재 {len(goals)}번)")
    if set(screens[0][ROWS - 1]) != {"#"}:
        sys.exit("오류: 맨 아래 화면(screen0)의 바닥 행은 전부 # 이어야 합니다")
    s, ty, tx = starts[0]
    below = screens[s][ty + 1][tx] if ty + 1 < ROWS else (screens[s - 1][0][tx] if s else "#")
    if below != "#":
        sys.exit("오류: S 바로 아래 칸은 # 이어야 합니다 (대기 상태로 시작하므로)")
    return starts[0]


def write_mem(screens, path: Path):
    # addr = {screen[2:0], ty[4:0], tx[5:0]}, 안 쓰는 주소는 1(막힘)
    mem = [1] * (1 << 14)
    for s, rows in enumerate(screens):
        for ty, r in enumerate(rows):
            for tx, c in enumerate(r):
                mem[(s << 11) | (ty << 6) | tx] = CODE[c]
    path.write_text("".join(f"{v:x}\n" for v in mem), encoding="ascii")


def write_json(screens, start, path: Path):
    s, ty, tx = start
    data = {"tile": TILE, "cols": COLS, "rows": ROWS,
            "start": {"screen": s, "x": tx * TILE, "y": ty * TILE},
            "screens": [[r.replace("S", ".") for r in rows] for rows in screens]}
    path.write_text(json.dumps(data, indent=1), encoding="utf-8")


def write_params(screens, start, path: Path):
    s, ty, tx = start
    block = (
        "// >>> make_map.py 가 생성하는 구간 (손으로 고치지 않는다)\n"
        f"localparam integer NUM_SCREENS  = {len(screens)};\n"
        f"localparam integer START_SCREEN = {s};\n"
        f"localparam integer START_X      = {tx * TILE};\n"
        f"localparam integer START_Y      = {ty * TILE};\n"
        "// <<< make_map.py")
    text = path.read_text(encoding="utf-8")
    new, n = re.subn(r"// >>> make_map\.py.*?// <<< make_map\.py", lambda m: block, text, flags=re.S)
    if n != 1:
        sys.exit(f"오류: {path} 에서 make_map.py 구간을 찾지 못했습니다")
    path.write_text(new, encoding="utf-8")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument("--maps", default=str(ROOT / "maps"))
    ap.add_argument("--mem", default=str(ROOT / "rtl" / "map.mem"))
    ap.add_argument("--json", default=str(ROOT / "pc" / "map.json"))
    ap.add_argument("--params", default=str(ROOT / "rtl" / "params.vh"))
    a = ap.parse_args()

    screens = load(Path(a.maps))
    start = check(screens)
    if a.mem != "-":
        write_mem(screens, Path(a.mem))
    if a.json != "-":
        write_json(screens, start, Path(a.json))
    if a.params != "-":
        write_params(screens, start, Path(a.params))
    s, ty, tx = start
    print(f"화면 {len(screens)}개, 시작 screen={s} x={tx * TILE} y={ty * TILE}")


if __name__ == "__main__":
    main()
