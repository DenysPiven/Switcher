#!/usr/bin/env python3
"""Renders docs/demo.gif: a short animation of how Switcher works.

Usage: python3 scripts/make_demo_gif.py  (needs Pillow and macOS system fonts)
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SCALE = 2  # render at 2x, then downscale for smooth edges
W, H = 800, 450
OUT = Path(__file__).resolve().parent.parent / "docs" / "demo.gif"

BG = (22, 23, 26)
MENU_BAR = (34, 35, 39)
WINDOW = (38, 39, 43)
SHADOW = (12, 12, 14)
BORDER = (62, 64, 70)
TEXT = (236, 237, 241)
MUTED = (150, 154, 163)
ACCENT = (10, 132, 255)
FIXED_BG = (32, 92, 52)
WRONG = (255, 105, 97)
KEY_BG = (78, 80, 88)
KEY_TEXT = (255, 255, 255)

FONT_PATH = "/System/Library/Fonts/SFNS.ttf"


def font(size, weight="Regular"):
    f = ImageFont.truetype(FONT_PATH, size * SCALE)
    f.set_variation_by_name(weight)
    return f


F_TEXT = font(26)
F_CAPTION = font(19, "Medium")
F_BADGE = font(13, "Semibold")
F_MENU = font(13, "Medium")
F_TITLE = font(13, "Semibold")
F_KEY = font(18, "Semibold")
F_END = font(30, "Bold")
F_END_SUB = font(18)


def s(v):
    return int(v * SCALE)


class Line:
    def __init__(self):
        self.text = ""
        self.state = "normal"  # normal | wrong | fixed


def render(lines, badge, caption, key=None, caret=True, badge_flash=False, end=False):
    img = Image.new("RGB", (s(W), s(H)), BG)
    d = ImageDraw.Draw(img)

    # Menu bar with the input source badge, like the real macOS one.
    d.rectangle([0, 0, s(W), s(30)], fill=MENU_BAR)
    d.line([0, s(30), s(W), s(30)], fill=BORDER, width=s(1))
    d.text((s(18), s(15)), "Switcher demo", font=F_MENU, fill=MUTED, anchor="lm")
    d.text((s(W - 18), s(15)), "10:41", font=F_MENU, fill=TEXT, anchor="rm")
    bx = s(W - 104)
    d.rounded_rectangle([bx, s(6), bx + s(40), s(24)], radius=s(5),
                        fill=ACCENT if badge_flash else TEXT)
    d.text((bx + s(20), s(15)), badge, font=F_BADGE, fill=KEY_TEXT if badge_flash else BG, anchor="mm")

    # Notes-like window.
    wx0, wy0, wx1, wy1 = s(80), s(58), s(W - 80), s(H - 80)
    d.rounded_rectangle([wx0 + s(2), wy0 + s(4), wx1 + s(2), wy1 + s(4)], radius=s(14), fill=SHADOW)
    d.rounded_rectangle([wx0, wy0, wx1, wy1], radius=s(14), fill=WINDOW, outline=BORDER, width=s(1))
    for i, c in enumerate([(255, 95, 87), (254, 188, 46), (40, 200, 64)]):
        cx, cy = wx0 + s(22 + i * 20), wy0 + s(20)
        d.ellipse([cx - s(6), cy - s(6), cx + s(6), cy + s(6)], fill=c)
    d.text(((wx0 + wx1) // 2, wy0 + s(20)), "Notes", font=F_TITLE, fill=MUTED, anchor="mm")
    d.line([wx0, wy0 + s(40), wx1, wy0 + s(40)], fill=BORDER, width=s(1))

    if end:
        cx, cy = (wx0 + wx1) // 2, (wy0 + s(40) + wy1) // 2
        d.text((cx, cy - s(18)), "Switcher", font=F_END, fill=TEXT, anchor="mm")
        d.text((cx, cy + s(24)), "Invisible. No lag. Just keep typing.", font=F_END_SUB, fill=MUTED, anchor="mm")
    else:
        x0, y = wx0 + s(28), wy0 + s(62)
        for i, line in enumerate(lines):
            if line.state == "fixed" and line.text.strip():
                tb =d.textbbox((x0, y), line.text.rstrip(), font=F_TEXT, anchor="lm")
                d.rounded_rectangle([tb[0] - s(5), y - s(19), tb[2] + s(5), y + s(19)], radius=s(6), fill=FIXED_BG)
            color = WRONG if line.state == "wrong" else TEXT
            d.text((x0, y), line.text, font=F_TEXT, fill=color, anchor="lm")
            if caret and i == len(lines) - 1:
                cx = x0 + int(d.textlength(line.text, font=F_TEXT)) + s(2)
                d.rectangle([cx, y - s(16), cx + s(2), y + s(16)], fill=ACCENT)
            y += s(52)

    # Pressed key overlay.
    if key:
        kw = int(d.textlength(key, font=F_KEY)) + s(36)
        kx1, ky1 = wx1 - s(20), wy1 - s(20)
        d.rounded_rectangle([kx1 - kw, ky1 - s(44), kx1, ky1], radius=s(10), fill=KEY_BG)
        d.text((kx1 - kw // 2, ky1 - s(22)), key, font=F_KEY, fill=KEY_TEXT, anchor="mm")

    # Caption under the window.
    d.text((s(W / 2), s(H - 40)), caption, font=F_CAPTION, fill=TEXT, anchor="mm")

    return img.resize((W, H), Image.LANCZOS)


frames = []  # (image, duration in ms)


def add(ms, **kw):
    frames.append((render(**kw), ms))


def hold(ms, **kw):
    """Hold a scene with a blinking caret."""
    on = True
    while ms > 0:
        step = min(500, ms)
        add(step, caret=on, **kw)
        on = not on
        ms -= step


def scene(lines, typed, fixed, layout_from, layout_to, caption_before, caption_after, key):
    line = Line()
    lines.append(line)
    hold(900, lines=lines, badge=layout_from, caption=caption_before)
    for ch in typed:
        line.text += ch
        add(130, lines=lines, badge=layout_from, caption=caption_before)
    line.state = "wrong"
    hold(600, lines=lines, badge=layout_from, caption=caption_before)
    add(450, lines=lines, badge=layout_from, caption=caption_before, key=key)
    line.text, line.state = fixed, "fixed"
    add(700, lines=lines, badge=layout_to, caption=caption_after, key=key, badge_flash=True)
    hold(1800, lines=lines, badge=layout_to, caption=caption_after)
    line.state = "normal"


lines = []
scene(lines, "ghbdsn", "привіт ", "EN", "UA",
      "Forgot to switch the layout? Just keep typing.",
      "Space: the word is fixed and the layout is switched.", "space")
scene(lines, "руддщ", "hello ", "UA", "EN",
      "It works both ways.",
      "Ukrainian ⇄ English, automatically.", "space")
scene(lines, "Ltybc", "Денис", "EN", "UA",
      "Names and rare words? Convert them yourself.",
      "Double ⇧ converts the last word (or undoes a fix).", "⇧  ⇧")
add(2600, lines=lines, badge="UA", caption="github.com/DenysPiven/Switcher", caret=False, end=True)

OUT.parent.mkdir(parents=True, exist_ok=True)
# One palette for all frames, so small accents (traffic lights, badge) keep their colors.
mosaic = Image.new("RGB", (W, H * len(frames)))
for i, (f, _) in enumerate(frames):
    mosaic.paste(f, (0, H * i))
palette = mosaic.quantize(colors=255, method=Image.Quantize.FASTOCTREE)
images = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f, _ in frames]
images[0].save(OUT, save_all=True, append_images=images[1:], duration=[ms for _, ms in frames],
               loop=0, optimize=True, disposal=1)
print(f"{OUT} ({len(frames)} frames, {OUT.stat().st_size // 1024} KB, "
      f"{sum(ms for _, ms in frames) / 1000:.1f} s)")
