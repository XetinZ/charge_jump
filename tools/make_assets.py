r"""ChatGPT 로 만든 원본 그림(pc\assets\src) → 뷰어용 그림(pc\assets).

  src\sprites.png   캐릭터 6동작 (마젠타 배경, 한 줄): 서기, 차지, 상승, 낙하, 착지, 승리
  src\tiles.png     타일 4개 (마젠타 배경, 한 줄): 숲 발판, 구름 발판, 우주 발판, 목표 별
  src\bg_forest.png, src\bg_sky.png, src\bg_space.png   배경 (4:3)

출력: bg0~2.png (640x480, 화면 0 숲 / 1 하늘 / 2 우주), tile0~2.png, goal.png (16x16),
      hero_idle/charge/rise/fall/land/win.png (24x24, 발밑 가운데 기준), preview.png (확인용 모음)

사용:  py tools\make_assets.py          (pip install pillow numpy)
원본이 ChatGPT 그림이라 정확한 픽셀 격자가 아니다. 줄일 때 칸마다 평균을 내고(BOX),
색 수를 줄여 작은 크기에서도 픽셀 그림처럼 보이게 한다.
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TILE = 16
SPRITE_W, SPRITE_H = 24, 24        # 캐릭터 그림 칸. 충돌 상자(16x16)의 발밑 가운데에 맞춰 그린다
HERO_H = 20                        # 서 있는 캐릭터의 키 [px]
SPRITE_NAMES = ["idle", "charge", "rise", "fall", "land", "win"]
TILE_NAMES = ["tile0", "tile1", "tile2", "goal"]
BG = {"bg0": "bg_forest", "bg1": "bg_sky", "bg2": "bg_space"}


def key_mask(a):
    """마젠타(배경) 판정. 가장자리의 섞인 색까지 넉넉히 잡는다."""
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    return (r > 170) & (b > 170) & (g < 110) & (np.abs(r - b) < 70)


def split_items(img, n):
    """마젠타가 아닌 부분을 가로 방향 빈 칸으로 나눠 n 개 상자를 찾는다 (큰 것부터 n 개)."""
    a = np.asarray(img.convert("RGB"))
    fg = ~key_mask(a)
    cols = fg.sum(axis=0) > 2
    spans, start = [], None
    for x, c in enumerate(list(cols) + [False]):
        if c and start is None:
            start = x
        elif not c and start is not None:
            spans.append((start, x))
            start = None
    # 아주 가까운 조각(목도리 끝 등)은 합친다
    merged = []
    for s in spans:
        if merged and s[0] - merged[-1][1] < 12:
            merged[-1] = (merged[-1][0], s[1])
        else:
            merged.append(s)
    merged = sorted(sorted(merged, key=lambda s: s[1] - s[0], reverse=True)[:n])
    if len(merged) != n:
        raise SystemExit(f"오류: {n}개를 기대했는데 {len(merged)}개를 찾았다")
    boxes = []
    for x0, x1 in merged:
        rows = np.where(fg[:, x0:x1].sum(axis=1) > 2)[0]
        boxes.append((x0, rows[0], x1, rows[-1] + 1))
    return boxes


def inset_box(img, box, limit=0.02):
    """네 변 각각, 그 줄의 마젠타 비율이 limit 이하가 될 때까지 안쪽으로 줄인다."""
    m = key_mask(np.asarray(img.convert("RGB")))
    x0, y0, x1, y1 = box
    while y1 - y0 > 8 and m[y0, x0:x1].mean() > limit: y0 += 1
    while y1 - y0 > 8 and m[y1 - 1, x0:x1].mean() > limit: y1 -= 1
    while x1 - x0 > 8 and m[y0:y1, x0].mean() > limit: x0 += 1
    while x1 - x0 > 8 and m[y0:y1, x1 - 1].mean() > limit: x1 -= 1
    return (x0, y0, x1, y1)


def cut_rgba(img, box):
    """상자를 잘라 마젠타를 투명으로."""
    a = np.asarray(img.convert("RGBA").crop(box)).copy()
    a[key_mask(a), 3] = 0
    return Image.fromarray(a, "RGBA")


def shrink(img, size, colors=32):
    """BOX 로 줄이고, 반투명은 0/255 로, 색 수는 줄인다."""
    small = img.resize(size, Image.BOX)
    a = np.asarray(small).copy()
    alpha = a[..., 3] >= 128
    rgb = Image.fromarray(a[..., :3]).quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGB")
    out = np.dstack([np.asarray(rgb), np.where(alpha, 255, 0).astype(np.uint8)])
    return Image.fromarray(out, "RGBA")


def make_tiles(src, dst):
    img = Image.open(src / "tiles.png")
    out = []
    for name, box in zip(TILE_NAMES, split_items(img, 4)):
        if name != "goal":                      # 발판은 가장자리 마젠타가 거의 없을 때까지 안쪽으로 잘라 칸을 꽉 채운다
            box = inset_box(img, box)
        t = cut_rgba(img, box)
        if name != "goal":
            a = np.asarray(t).copy()
            a[..., 3] = 255
            t = Image.fromarray(a, "RGBA")
        t = shrink(t, (TILE, TILE), colors=24)
        t.save(dst / f"{name}.png")
        out.append(t)
    return out


def make_sprites(src, dst):
    img = Image.open(src / "sprites.png")
    boxes = split_items(img, 6)
    scale = HERO_H / (boxes[0][3] - boxes[0][1])        # 서기 동작의 키를 기준으로 모두 같은 비율
    out = []
    for name, box in zip(SPRITE_NAMES, boxes):
        t = cut_rgba(img, box)
        w = max(1, round(t.width * scale))
        h = max(1, round(t.height * scale))
        if w > SPRITE_W or h > SPRITE_H:                # 칸을 넘으면 비율을 지켜 더 줄인다
            k = min(SPRITE_W / w, SPRITE_H / h)
            w, h = max(1, int(w * k)), max(1, int(h * k))
        t = shrink(t, (w, h), colors=16)
        canvas = Image.new("RGBA", (SPRITE_W, SPRITE_H), (0, 0, 0, 0))
        canvas.paste(t, ((SPRITE_W - w) // 2, SPRITE_H - h), t)   # 발밑 가운데
        canvas.save(dst / f"hero_{name}.png")
        out.append(canvas)
    return out


def make_backgrounds(src, dst):
    out = []
    for name, srcname in BG.items():
        img = Image.open(src / f"{srcname}.png").convert("RGB")
        w, h = img.size
        if abs(w / h - 4 / 3) > 0.01:                   # 4:3 이 아니면 가운데를 잘라 맞춘다
            if w / h > 4 / 3:
                nw = round(h * 4 / 3)
                img = img.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
            else:
                nh = round(w * 3 / 4)
                img = img.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
        img = img.resize((640, 480), Image.BOX)
        img.save(dst / f"{name}.png")
        out.append(img)
    return out


def preview(bgs, tiles, sprites, path):
    """배경마다 발판 한 줄과 캐릭터를 얹은 확인용 그림 (2배 확대)."""
    sheet = Image.new("RGB", (640 * 3 + 20, 480), "white")
    for i, bg in enumerate(bgs):
        frame = bg.copy().convert("RGBA")
        for tx in range(8, 24):
            frame.alpha_composite(tiles[i], (tx * TILE, 400))
        frame.alpha_composite(tiles[3], (24 * TILE, 384))
        for j, s in enumerate(sprites):
            frame.alpha_composite(s, (150 + j * 40, 400 - SPRITE_H))
        sheet.paste(frame.convert("RGB"), (i * 650, 0))
    sheet.save(path)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument("--src", default=str(ROOT / "pc" / "assets" / "src"))
    ap.add_argument("--dst", default=str(ROOT / "pc" / "assets"))
    a = ap.parse_args()
    src, dst = Path(a.src), Path(a.dst)
    tiles = make_tiles(src, dst)
    sprites = make_sprites(src, dst)
    bgs = make_backgrounds(src, dst)
    preview(bgs, tiles, sprites, dst / "preview.png")
    print(f"{dst} 에 배경 3장, 타일 4개, 캐릭터 {len(sprites)}동작, preview.png 저장")


if __name__ == "__main__":
    main()
