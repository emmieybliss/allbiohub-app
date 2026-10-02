"""Builds the app icon, splash and store icon from the official logo.

    python3 tool/brand/make_icons.py

Needs Pillow and numpy. Reads tool/brand/allbiohub_media_logo.jpg (the
AllBioHub Media logo) and writes the Android launcher icons, the splash image,
the Play Store icon and the in-app logo mark. Re-run it if the logo changes.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tool/brand/allbiohub_media_logo.jpg"
RES = ROOT / "android/app/src/main/res"

# The circle-and-silhouette mark inside the full logo (pixels of the source).
MARK_BOX = (359, 195, 829, 665)
# Inside the mark: the ring's disc and the play badge, which are solid white
# where the source shows white (everything else white is background).
RING = (235, 235, 205)  # centre x, centre y, radius (to mid-ring)
BADGE = (378, 368, 77)

DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def mark(keep_white_inside=True):
    """The mark on a transparent background."""
    rgb = np.asarray(
        Image.open(SOURCE).convert("RGB").crop(MARK_BOX), dtype=np.float64
    )
    h, w, _ = rgb.shape
    # How far each pixel is from the off-white page.
    distance = (248 - rgb).max(axis=2)
    alpha = np.clip(distance / 48, 0, 1)
    # Undo the blend with white so edges keep their real colour.
    safe = np.maximum(alpha, 1e-3)[..., None]
    color = np.clip((rgb - (1 - safe) * 255) / safe, 0, 255)

    if keep_white_inside:
        ys, xs = np.mgrid[0:h, 0:w]
        inside = np.zeros((h, w), bool)
        for cx, cy, r in (RING, BADGE):
            inside |= (xs - cx) ** 2 + (ys - cy) ** 2 <= r**2
        inside_alpha = alpha[inside][..., None]
        color[inside] = (
            color[inside] * inside_alpha + 255 * (1 - inside_alpha)
        )
        alpha[inside] = 1

    out = np.dstack([color, alpha * 255]).round().astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def place(img, canvas, size, background=None, shape=None):
    """`img` scaled to `size` px, centred on a `canvas` px square."""
    base = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    if background:
        mask = Image.new("L", (canvas * 4, canvas * 4), 0)
        draw = ImageDraw.Draw(mask)
        box = (0, 0, canvas * 4 - 1, canvas * 4 - 1)
        if shape == "circle":
            draw.ellipse(box, fill=255)
        elif shape == "rounded":
            draw.rounded_rectangle(box, radius=canvas * 4 * 0.22, fill=255)
        else:
            draw.rectangle(box, fill=255)
        mask = mask.resize((canvas, canvas), Image.LANCZOS)
        base.paste(Image.new("RGBA", (canvas, canvas), background), (0, 0), mask)
    scaled = img.resize((size, size), Image.LANCZOS)
    offset = (canvas - size) // 2
    base.alpha_composite(scaled, (offset, offset))
    return base


def monochrome(img):
    """White shape for Android 13 themed icons; the launcher tints it."""
    alpha = img.getchannel("A")
    white = Image.new("RGBA", img.size, (255, 255, 255, 0))
    white.putalpha(alpha)
    return white


def main():
    full = mark()
    flat = mark(keep_white_inside=False)
    for name, scale in DENSITIES.items():
        folder = RES / f"mipmap-{name}"
        # Adaptive icon layers are 108dp; the mark sits inside the 66dp safe
        # zone so no launcher mask clips the play badge.
        layer = round(108 * scale)
        inner = round(58 * scale)
        place(full, layer, inner).save(folder / "ic_launcher_foreground.png")
        place(monochrome(flat), layer, inner).save(
            folder / "ic_launcher_monochrome.png"
        )
        # Older Android: a 48dp white circle with the mark.
        legacy = round(48 * scale)
        place(full, legacy, round(40 * scale), "white", "circle").save(
            folder / "ic_launcher.png"
        )
        # Pre-Android 12 launch screen: the mark at 120dp.
        place(full, round(120 * scale), round(120 * scale)).save(
            folder / "splash_logo.png"
        )

    # Play Store: 512 px, full square (Google rounds the corners).
    place(full, 512, 400, "white").convert("RGB").save(
        ROOT / "assets/branding/play_store_icon_512.png"
    )
    # In the app (splash, onboarding): the mark at up to 128dp, 4x.
    full.resize((512, 512), Image.LANCZOS).save(
        ROOT / "assets/branding/logo_mark.png", optimize=True
    )


if __name__ == "__main__":
    main()
