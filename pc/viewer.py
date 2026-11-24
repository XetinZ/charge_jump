r"""차지 점프 뷰어 — FPGA 가 UART 로 보낸 상태를 그대로 그리기만 한다.

게임 로직(위치·속도·충돌 계산, 보간, 예측)은 넣지 않는다. 패킷이 없거나 깨진 프레임에서는
마지막으로 받은 값을 다시 그린다.

사용:  py pc\viewer.py COM3
       py pc\viewer.py COM3 --csv log.csv
필요:  pip install pygame pyserial
"""
import argparse
import csv
import json
import math
import struct
import time
from pathlib import Path

HEADER = b"\xAA\x55"
PKT_LEN = 11
STATE_NAMES = ("IDLE", "CHARGE", "AIR", "CLEAR")
# 상태 바이트 7:6 = 어둠 단계 (FPGA 가 CDS 센서로 정함). 0 = 덮지 않음, 1~3 = 캐릭터 주변 이 반지름만 보임
DARK_RADIUS = (None, 120, 56, 24)
DARK_ALPHA = 245

HUD_H = 40
BG, WALL, WALL_EDGE, GOAL = (18, 20, 32), (92, 104, 128), (130, 144, 172), (250, 204, 60)
BODY, EYE, ARROW, TEXT, DIM = (236, 96, 72), (255, 255, 255), (120, 220, 255), (230, 232, 240), (120, 126, 140)


class PacketParser:
    """바이트 스트림에서 패킷을 꺼낸다 (명세 4장 'PC 측 해석')."""

    def __init__(self):
        self.buf = bytearray()
        self.nbytes = 0                                 # 받은 바이트 수 (통신 진단용)
        self.good = 0
        self.bad = 0

    def feed(self, data):
        self.nbytes += len(data)
        self.buf += data
        out = []
        while True:
            i = self.buf.find(HEADER)
            if i < 0:                                   # 헤더 없음: 마지막 0xAA 만 남긴다
                del self.buf[:-1 if self.buf.endswith(b"\xAA") else len(self.buf)]
                break
            del self.buf[:i]
            if len(self.buf) < PKT_LEN:
                break
            body = self.buf[2:PKT_LEN]                  # 9바이트: 값 8 + 체크섬 1
            cs = 0
            for b in body[:8]:
                cs ^= b
            if cs != body[8]:                           # 버리고 한 바이트 뒤에서 다시 찾는다
                self.bad += 1
                del self.buf[:1]
                continue
            out.append(struct.unpack(">hhBBBB", bytes(body[:8])))
            self.good += 1
            del self.buf[:PKT_LEN]
        return out


ASSET_DIR = Path(__file__).with_name("assets")
HERO_SIZE = 24          # 캐릭터 그림 칸. 충돌 상자(16x16)의 발밑 가운데에 맞춘다
LAND_SHOW = 8           # 착지 그림을 보여주는 프레임 수 (그림 효과)


def load_assets(pg):
    """pc/assets 의 그림을 읽는다. 하나라도 없으면 None (도형으로 그린다). tools/make_assets.py 가 만든다."""
    names = ([f"bg{i}" for i in range(3)] + [f"tile{i}" for i in range(3)] + ["goal"] +
             [f"hero_{n}" for n in ("idle", "charge", "rise", "fall", "land", "win")])
    try:
        return {n: pg.image.load(str(ASSET_DIR / f"{n}.png")).convert_alpha() for n in names}
    except (FileNotFoundError, pg.error):
        return None


def draw_map(pg, surf, rows, tile, assets=None, index=0):
    surf.fill(BG)
    k = min(index, 2)
    if assets:
        surf.blit(assets[f"bg{k}"], (0, 0))
    for ty, row in enumerate(rows):
        for tx, ch in enumerate(row):
            r = pg.Rect(tx * tile, ty * tile, tile, tile)
            if ch == "#":
                if assets:
                    surf.blit(assets[f"tile{k}"], r.topleft)
                else:
                    pg.draw.rect(surf, WALL, r)
                    pg.draw.line(surf, WALL_EDGE, r.topleft, (r.right - 1, r.top))
            elif ch == "G":
                if assets:
                    surf.blit(assets["goal"], r.topleft)
                else:
                    pg.draw.rect(surf, GOAL, r.inflate(-4, -4), border_radius=3)


def make_dark_masks(pg, w, h):
    """어둠 단계별로 가운데에 구멍이 뚫린 덮개를 미리 만든다. 캐릭터 중심에 덮개 중심을 맞춰 그린다."""
    masks = [None]
    for r in DARK_RADIUS[1:]:
        m = pg.Surface((w * 2, h * 2), pg.SRCALPHA)
        m.fill((0, 0, 0, DARK_ALPHA))
        steps = 8                                   # 가장자리를 부드럽게
        for i in range(steps, -1, -1):
            rr = int(r * (1 + 0.5 * i / steps))
            pg.draw.circle(m, (0, 0, 0, int(DARK_ALPHA * i / steps)), (w, h), rr)
        masks.append(m)
    return masks


def make_sprite(pg, tile):
    """16x16 캐릭터 (오른쪽을 보는 모양). 왼쪽은 좌우 반전해서 쓴다."""
    s = pg.Surface((tile, tile), pg.SRCALPHA)
    pg.draw.rect(s, BODY, (1, 2, tile - 2, tile - 2), border_radius=3)
    pg.draw.rect(s, EYE, (tile - 6, 5, 3, 4))
    pg.draw.rect(s, (40, 20, 20), (tile - 4, 6, 1, 2))
    return s


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument("port", help="시리얼 포트 (예: COM3, /dev/ttyUSB0)")
    ap.add_argument("--baud", type=int, default=19200, help="params.vh 의 BAUD 와 같게 (기본 19200)")
    ap.add_argument("--map", default=str(Path(__file__).with_name("map.json")))
    ap.add_argument("--csv", help="받은 패킷을 CSV 로 저장 (디버그용)")
    ap.add_argument("--scale", type=int, default=1, help="화면 확대 배율")
    a = ap.parse_args()

    import pygame as pg
    import serial

    m = json.loads(Path(a.map).read_text(encoding="utf-8"))
    tile, w, h = m["tile"], m["cols"] * m["tile"], m["rows"] * m["tile"]

    ser = serial.Serial(a.port, a.baud, timeout=0)
    log = None
    if a.csv:
        log_f = open(a.csv, "w", newline="")
        log = csv.writer(log_f)
        log.writerow(["t", "x", "y", "screen", "charge", "angle", "status"])

    pg.init()
    win = pg.display.set_mode((w * a.scale, (h + HUD_H) * a.scale))
    pg.display.set_caption("Charge Jump Viewer")
    canvas = pg.Surface((w, h + HUD_H))
    font = pg.font.Font(None, 20)
    big = pg.font.Font(None, 72)
    sprite_r = make_sprite(pg, tile)
    sprite_l = pg.transform.flip(sprite_r, True, False)
    dark_masks = make_dark_masks(pg, w, h)
    assets = load_assets(pg)
    hero = {}
    if assets:
        for n in ("idle", "charge", "rise", "fall", "land", "win"):
            img = assets[f"hero_{n}"]
            hero[(n, False)] = img
            hero[(n, True)] = pg.transform.flip(img, True, False)
    map_surfs = []
    for i, rows in enumerate(m["screens"]):
        s = pg.Surface((w, h))
        draw_map(pg, s, rows, tile, assets, i)
        map_surfs.append(s)
    land_left = 0               # 착지 그림을 남은 몇 프레임 더 보여줄지 (그림 효과일 뿐 게임과 무관)

    parser = PacketParser()
    last = None                 # (x, y, screen, charge, angle, status) — 마지막으로 받은 값
    last_time = 0.0
    t0 = time.time()
    clock = pg.time.Clock()
    running = True

    while running:
        for e in pg.event.get():
            if e.type == pg.QUIT or (e.type == pg.KEYDOWN and e.key == pg.K_ESCAPE):
                running = False

        n = ser.in_waiting
        if n:
            for pkt in parser.feed(ser.read(n)):
                last, last_time = pkt, time.time()
                if pkt[5] & 0x10:                          # 착지 비트
                    land_left = LAND_SHOW
                elif land_left:
                    land_left -= 1
                if log:
                    log.writerow([f"{last_time - t0:.4f}", *pkt])

        canvas.fill(BG)
        if last is None:
            canvas.blit(font.render(f"waiting for packets on {a.port} @ {a.baud} ...", True, DIM), (16, 16))
            # 진단: 바이트가 전혀 안 오면 핀·포트 문제, 오는데 패킷이 안 맞으면 클록·속도 문제
            diag = f"bytes received {parser.nbytes}   bad packets {parser.bad}"
            canvas.blit(font.render(diag, True, BODY if parser.nbytes else DIM), (16, 40))
            if parser.nbytes == 0:
                hint = "no bytes: check bitstream, DIP3 (UART pin F6/C6), cable"
            else:
                hint = "bytes but no packet: check CLOCK SELECT = 1MHz and --baud"
            canvas.blit(font.render(hint, True, DIM), (16, 64))
        else:
            x, y, scr_byte, charge, angle, status = last
            screen, rising = scr_byte & 7, bool(scr_byte & 8)
            state, left, taylor = status & 3, bool(status & 4), bool(status & 8)
            dark = (status >> 6) & 3
            if screen < len(map_surfs):
                canvas.blit(map_surfs[screen], (0, 0))
            if hero:
                # 그림 고르기: 모두 FPGA 가 보낸 상태 비트로 정한다
                pose = ("win" if state == 3 else "charge" if state == 1 else
                        ("rise" if rising else "fall") if state == 2 else
                        "land" if land_left else "idle")
                canvas.blit(hero[(pose, left)], (x + tile // 2 - HERO_SIZE // 2, y + tile - HERO_SIZE))
            else:
                canvas.blit(sprite_l if left else sprite_r, (x, y))

            # 각도 화살표 (표시용 삼각함수. 게임 결과와 무관)
            if state in (0, 1):
                cx, cy = x + tile // 2, y + tile // 2
                length = 22 + charge // 2
                rad = math.radians(angle)
                ex, ey = cx + length * math.cos(rad), cy - length * math.sin(rad)
                pg.draw.line(canvas, ARROW, (cx, cy), (ex, ey), 2)
                pg.draw.circle(canvas, ARROW, (int(ex), int(ey)), 3)

            # 어둠 (FPGA 가 정한 단계를 그대로 그린다)
            if dark:
                cx, cy = x + tile // 2, y + tile // 2
                canvas.set_clip(pg.Rect(0, 0, w, h))
                canvas.blit(dark_masks[dark], (cx - w, cy - h))
                canvas.set_clip(None)

            if state == 3:
                t = big.render("CLEAR!", True, GOAL)
                canvas.blit(t, t.get_rect(center=(w // 2, h // 2)))

            # HUD: 차지 게이지, 각도, 상태, 삼각함수 모드
            pg.draw.rect(canvas, (10, 11, 18), (0, h, w, HUD_H))
            pg.draw.rect(canvas, DIM, (12, h + 12, 130, 16), 1)
            pg.draw.rect(canvas, GOAL if charge == 63 else BODY, (14, h + 14, charge * 2, 12))
            hud = (f"ANGLE {angle:3d}   {STATE_NAMES[state]:6s}  SCREEN {screen}   "
                   f"TRIG {'TAYLOR' if taylor else 'ROM'}" + (f"   DARK {dark}" if dark else ""))
            canvas.blit(font.render(hud, True, TEXT), (156, h + 13))
            stale = time.time() - last_time > 0.5
            stat = f"ok {parser.good}  bad {parser.bad}" + ("  NO SIGNAL" if stale else "")
            t = font.render(stat, True, BODY if (stale or parser.bad) else DIM)
            canvas.blit(t, (w - t.get_width() - 12, h + 13))

        if a.scale == 1:
            win.blit(canvas, (0, 0))
        else:
            pg.transform.scale(canvas, win.get_size(), win)
        pg.display.flip()
        clock.tick(60)

    if log:
        log_f.close()
    ser.close()
    pg.quit()


if __name__ == "__main__":
    main()
