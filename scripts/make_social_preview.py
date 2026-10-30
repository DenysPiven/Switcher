#!/usr/bin/env python3
"""Renders docs/social-preview.png (1280x640), the image shown when the repo link is shared.

Upload it in GitHub: Settings → General → Social preview.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

W, H = 1280, 640
OUT = Path(__file__).resolve().parent.parent / "docs" / "social-preview.png"

BG = (22, 23, 26)
CARD = (38, 39, 43)
BORDER = (62, 64, 70)
TEXT = (236, 237, 241)
MUTED = (150, 154, 163)
ACCENT = (10, 132, 255)
WRONG = (255, 105, 97)
FIXED_BG = (32, 92, 52)


def font(size, weight="Regular"):
    f = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size)
    f.set_variation_by_name(weight)
    return f


img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img)

d.text((96, 150), "Switcher", font=font(96, "Bold"), fill=TEXT, anchor="ls")
d.text((96, 210), "Invisible keyboard layout switcher for macOS", font=font(38), fill=MUTED, anchor="ls")

# Before → after examples.
y = 270
for wrong, fixed in [("ghbdsn", "привіт"), ("руддщ", "hello")]:
    d.rounded_rectangle([96, y, 1184, y + 110], radius=22, fill=CARD, outline=BORDER, width=2)
    f = font(52, "Medium")
    d.text((150, y + 55), wrong, font=f, fill=WRONG, anchor="lm")
    d.text((560, y + 55), "→", font=f, fill=MUTED, anchor="mm")
    box = d.textbbox((680, y + 55), fixed, font=f, anchor="lm")
    d.rounded_rectangle([box[0] - 14, y + 24, box[2] + 14, y + 86], radius=12, fill=FIXED_BG)
    d.text((680, y + 55), fixed, font=f, fill=TEXT, anchor="lm")
    y += 140

d.text((96, 600), "Free · Open source · No lag · English & Ukrainian", font=font(30, "Medium"), fill=ACCENT, anchor="ls")

OUT.parent.mkdir(parents=True, exist_ok=True)
img.save(OUT, optimize=True)
print(OUT)
