#!/usr/bin/env python3
"""Composite raw device screenshots onto Betty-branded App Store frames.

Output keeps the source pixel dimensions exactly (ASC validates per display type).
Usage: frame.py <indir> <outdir>
"""
import sys, os, glob
from PIL import Image, ImageDraw, ImageFont, ImageFilter

INK = (13, 14, 21)          # Palette.ink #0D0E15
ORANGE = (255, 90, 58)      # Palette.orange #FF5A3A
LIME = (147, 224, 30)       # hero green
WHITE = (245, 246, 250)

HEAVY = "/System/Library/Fonts/Supplemental/Arial Black.ttf"

# (line, color) pairs per screenshot, in Betty's punchy uppercase voice.
CAPTIONS = {
    "01_home":        [("ALL YOUR GROUPS.", WHITE), ("ONE CHAMPION.", LIME)],
    "02_bet":         [("CALL THE SCORE", WHITE), ("BEFORE KICKOFF.", ORANGE)],
    "03_leaderboard": [("CLIMB THE", WHITE), ("LEADERBOARD.", ORANGE)],
    "04_chat":        [("TALK TRASH IN", WHITE), ("THE GROUP CHAT.", LIME)],
    "05_browse":      [("FIND YOUR CREW.", WHITE), ("MAKE YOUR CALLS.", ORANGE)],
}


def radial(size, center, radius, color, max_alpha):
    """Soft radial glow, rendered small then upscaled for a smooth falloff."""
    sw, sh = 240, int(240 * size[1] / size[0])
    g = Image.new("L", (sw, sh), 0)
    px = g.load()
    cx, cy = center[0] * sw, center[1] * sh
    r = radius * sw
    for y in range(sh):
        for x in range(sw):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            v = max(0.0, 1.0 - d / r)
            px[x, y] = int(max_alpha * v * v)
    g = g.resize(size, Image.BICUBIC)
    solid = Image.new("RGB", size, color)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.paste(solid, (0, 0), g)
    return out


def background(W, H):
    bg = Image.new("RGB", (W, H), INK)
    bg = Image.alpha_composite(bg.convert("RGBA"), radial((W, H), (0.5, 0.12), 0.85, ORANGE, 80))
    bg = Image.alpha_composite(bg, radial((W, H), (0.12, 0.9), 0.7, (67, 79, 142), 70))
    bg = Image.alpha_composite(bg, radial((W, H), (0.92, 0.78), 0.55, ORANGE, 35))
    return bg.convert("RGB")


def fit_font(draw, text, max_w, start):
    size = start
    while size > 24:
        f = ImageFont.truetype(HEAVY, size)
        if draw.textlength(text, font=f) <= max_w:
            return f
        size -= 2
    return ImageFont.truetype(HEAVY, size)


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0], img.size[1]], radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def frame(path, outdir):
    key = os.path.splitext(os.path.basename(path))[0]
    shot = Image.open(path).convert("RGBA")
    W, H = shot.size
    canvas = background(W, H).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    # Caption block (auto-fit to ~86% width).
    lines = CAPTIONS.get(key, [(key.upper(), WHITE)])
    max_w = int(W * 0.86)
    base = int(W * 0.085)
    fonts = [fit_font(draw, t, max_w, base) for t, _ in lines]
    fsize = min(f.size for f in fonts)
    fonts = [ImageFont.truetype(HEAVY, fsize) for _ in lines]
    line_h = int(fsize * 1.16)
    y = int(H * 0.055)
    for (text, color), f in zip(lines, fonts):
        w = draw.textlength(text, font=f)
        draw.text(((W - w) / 2, y), text, font=f, fill=color)
        y += line_h

    # Floating screenshot: rounded + soft shadow, centered, bleeding off the bottom.
    shot_w = int(W * 0.84)
    shot_h = int(shot_w * H / W)
    shot_r = int(shot_w * 0.052)
    shot = shot.resize((shot_w, shot_h), Image.LANCZOS)
    shot = rounded(shot, shot_r)
    sx = (W - shot_w) // 2
    sy = int(y + H * 0.03)

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sh_layer = Image.new("RGBA", shot.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh_layer).rounded_rectangle([0, 0, shot_w, shot_h], shot_r, fill=(0, 0, 0, 170))
    shadow.paste(sh_layer, (sx, sy + int(H * 0.012)), sh_layer)
    shadow = shadow.filter(ImageFilter.GaussianBlur(int(W * 0.03)))
    canvas = Image.alpha_composite(canvas, shadow)
    canvas.paste(shot, (sx, sy), shot)

    os.makedirs(outdir, exist_ok=True)
    out = os.path.join(outdir, key + ".png")
    canvas.convert("RGB").save(out, "PNG")
    print(f"  {key}: {W}x{H}")


if __name__ == "__main__":
    indir, outdir = sys.argv[1], sys.argv[2]
    for p in sorted(glob.glob(os.path.join(indir, "0*.png"))):
        frame(p, outdir)
