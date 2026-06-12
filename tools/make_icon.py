"""Generate the SleepytimeApp launch icon (PNG + ICO) with Pillow.

Run:  python tools/make_icon.py
Outputs app_icon.png (1024) and app_icon.ico in the repo root.
A cozy crescent-moon-with-a-sleeping-face on a night-sky squircle.
"""

import math
from PIL import Image, ImageDraw

S = 1024
TOP = (52, 40, 104)     # deep indigo (night sky top)
BOT = (103, 80, 164)    # #6750A4 (app seed colour)
CREAM = (255, 244, 214, 255)
FACE = (74, 58, 140, 255)
CHEEK = (233, 150, 170, 170)


def gradient_bg() -> Image.Image:
    bg = Image.new("RGB", (S, S))
    d = ImageDraw.Draw(bg)
    for y in range(S):
        t = y / (S - 1)
        d.line(
            [(0, y), (S, y)],
            fill=(
                int(TOP[0] + (BOT[0] - TOP[0]) * t),
                int(TOP[1] + (BOT[1] - TOP[1]) * t),
                int(TOP[2] + (BOT[2] - TOP[2]) * t),
            ),
        )
    return bg.convert("RGBA")


def star(draw: ImageDraw.ImageDraw, cx, cy, outer, inner, fill):
    pts = []
    for k in range(8):
        ang = math.radians(k * 45 - 90)
        r = outer if k % 2 == 0 else inner
        pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    draw.polygon(pts, fill=fill)


def build() -> Image.Image:
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # Rounded "squircle" background.
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=232, fill=255)
    img.paste(gradient_bg(), (0, 0), mask)

    draw = ImageDraw.Draw(img)

    # Scattered stars.
    for (x, y, o, i, a) in [
        (185, 205, 46, 16, 240),
        (315, 430, 24, 9, 200),
        (835, 235, 40, 15, 235),
        (735, 460, 22, 8, 190),
        (865, 660, 28, 10, 210),
        (180, 770, 30, 11, 215),
        (430, 835, 20, 7, 185),
    ]:
        star(draw, x, y, o, i, (255, 255, 255, a))

    # Crescent moon (carve an offset disc out of a full disc via a mask).
    cx, cy, R = 610, 560, 250
    mmask = Image.new("L", (S, S), 0)
    md = ImageDraw.Draw(mmask)
    md.ellipse([cx - R, cy - R, cx + R, cy + R], fill=255)
    ox, oy, OR = cx + 135, cy - 80, 240
    md.ellipse([ox - OR, oy - OR, ox + OR, oy + OR], fill=0)
    img.paste(Image.new("RGBA", (S, S), CREAM), (0, 0), mmask)

    # Sleeping face on the visible (left) lobe of the crescent.
    ex, ey = 505, 545
    draw.arc([ex - 48, ey - 34, ex + 48, ey + 30], start=205, end=335, fill=FACE, width=12)
    draw.arc([ex - 55, ey + 22, ex + 55, ey + 120], start=20, end=160, fill=FACE, width=13)
    draw.ellipse([ex - 92, ey + 14, ex - 56, ey + 50], fill=CHEEK)

    return img


def main():
    img = build()
    img.save("app_icon.png")
    img.resize((256, 256), Image.LANCZOS).save(
        "app_icon.ico", sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    )
    print("Wrote app_icon.png and app_icon.ico")


if __name__ == "__main__":
    main()
