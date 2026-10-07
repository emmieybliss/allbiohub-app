"""Builds the Google Play feature graphic (1024 x 500) from the logo.

    python3 tool/brand/make_feature_graphic.py

Needs Pillow and numpy. Writes assets/branding/play_feature_graphic.png,
the banner Google Play shows at the top of the store listing.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_icons import ROOT, mark  # noqa: E402

PURPLE = (79, 61, 173)
DEEP = (44, 32, 112)
ORANGE = (255, 122, 61)
LAVENDER = (214, 207, 255)
WIDTH, HEIGHT = 1024, 500


def font(name, size, weight=None):
    f = ImageFont.truetype(str(ROOT / "assets/fonts" / name), size)
    if weight:
        f.set_variation_by_axes([weight])
    return f


def main():
    # Purple, darkening toward the bottom right.
    img = Image.new("RGB", (WIDTH, HEIGHT), PURPLE)
    draw = ImageDraw.Draw(img)
    for x in range(WIDTH):
        for y in range(0, HEIGHT, 4):
            t = min(1, (x / WIDTH) * 0.6 + (y / HEIGHT) * 0.4)
            c = tuple(round(a + (b - a) * t) for a, b in zip(PURPLE, DEEP))
            draw.line([(x, y), (x, y + 3)], fill=c)

    # The mark on a white disc, left of centre.
    disc = 300
    cx, cy = 230, HEIGHT // 2
    layer = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(
        (cx - disc // 2, cy - disc // 2, cx + disc // 2, cy + disc // 2),
        fill=(255, 255, 255, 255),
    )
    logo = mark().resize((250, 250), Image.LANCZOS)
    layer.alpha_composite(logo, (cx - 125, cy - 125))
    img = Image.alpha_composite(img.convert("RGBA"), layer)

    draw = ImageDraw.Draw(img)
    left = 440
    title = font("PlayfairDisplay.ttf", 84, 800)
    draw.text((left, 120), "AllBio", font=title, fill="white")
    hub_x = left + draw.textlength("AllBio", font=title)
    draw.text((hub_x, 120), "Hub", font=title, fill=ORANGE)
    body = font("Inter.ttf", 32, 500)
    for i, line in enumerate(
        ["Stories shaping Africa,", "and the startups behind them."]
    ):
        draw.text((left, 248 + i * 44), line, font=body, fill=LAVENDER)

    img.convert("RGB").save(
        ROOT / "assets/branding/play_feature_graphic.png", optimize=True
    )


if __name__ == "__main__":
    main()
