#!/usr/bin/env python3
"""Derives the platform icon sources from the logo, assets/mpv_studio.png.

Run from the repository root, then let flutter_launcher_icons size them:

    python3 tool/app_icons.py
    dart run flutter_launcher_icons

Needs Pillow. Writes:

- assets/icon/android_foreground.png: the logo with its disc as wide as the
  72 dp visible area of the 108 dp adaptive canvas, so a round launcher shows
  exactly the logo; the ring and the play triangle stay inside the 66 dp safe
  circle, and the graphite disc melts into the graphite background layer.
- assets/icon/android_monochrome.png: the ring and the triangle as one white
  shape, same geometry, for Android 13 themed icons.
- assets/icon/ios.png: the logo flattened on graphite, with no alpha, as the
  App Store wants (flutter_launcher_icons' own alpha removal tints the
  antialiased disc edge green).
- assets/icon/macos.png: the logo on Apple's 1024 grid (an 824 body with a
  soft drop shadow).
- windows/runner/resources/app_icon.ico: every Windows size, 16 to 256.
- linux/runner/resources/app_icon.png: the window icon the Linux runner loads.
"""

import math
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
LOGO = ROOT / "assets" / "mpv_studio.png"
GRAPHITE = (0x24, 0x28, 0x2D)
RING_GREY = 0xBF
CANVAS = 1024

# Adaptive icons: 108 dp canvas, 72 dp visible, 66 dp safe circle.
ADAPTIVE_DISC = 72 / 108
ADAPTIVE_SAFE_RADIUS = 33 / 108


def content_radius(logo):
    """How far the light marks (ring, triangle) reach from the centre."""
    px = logo.load()
    c = (logo.width - 1) / 2
    reach = 0.0
    for y in range(logo.height):
        for x in range(logo.width):
            r, _, _, a = px[x, y]
            if a == 255 and r > GRAPHITE[0] + 8:
                reach = max(reach, math.hypot(x - c, y - c))
    return reach


def centred(image, size):
    """[image] scaled to [size] px, centred on a transparent canvas."""
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    scaled = image.resize((size, size), Image.LANCZOS)
    offset = (CANVAS - size) // 2
    canvas.alpha_composite(scaled, (offset, offset))
    return canvas


def monochrome(logo):
    """The light marks as one white shape: graphite is clear, the ring grey
    and the white triangle are both opaque."""
    r, _, _, a = logo.split()
    span = RING_GREY - GRAPHITE[0]
    alpha = r.point(lambda v: max(0, min(255, (v - GRAPHITE[0]) * 255 // span)))
    alpha = Image.composite(alpha, Image.new("L", logo.size, 0), a)
    white = Image.new("RGBA", logo.size, (255, 255, 255, 0))
    white.putalpha(alpha)
    return white


def macos(logo):
    """Apple's grid: an 824 px body centred on 1024, with a soft shadow."""
    body = 824
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    shadow_alpha = centred(logo, body).split()[3].point(lambda v: v * 3 // 10)
    shadow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    shadow.putalpha(shadow_alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    canvas.alpha_composite(shadow, (0, 10))
    canvas.alpha_composite(centred(logo, body))
    return canvas


def main():
    logo = Image.open(LOGO).convert("RGBA")
    adaptive_size = round(CANVAS * ADAPTIVE_DISC)
    reach = content_radius(logo) / logo.width * adaptive_size / CANVAS
    assert reach <= ADAPTIVE_SAFE_RADIUS, "the marks leave the safe zone"

    icons = ROOT / "assets" / "icon"
    icons.mkdir(exist_ok=True)
    centred(logo, adaptive_size).save(icons / "android_foreground.png")
    centred(monochrome(logo), adaptive_size).save(icons / "android_monochrome.png")
    ios = Image.new("RGBA", logo.size, GRAPHITE + (255,))
    ios.alpha_composite(logo)
    ios.convert("RGB").save(icons / "ios.png")
    macos(logo).save(icons / "macos.png")

    sizes = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256]
    logo.save(
        ROOT / "windows" / "runner" / "resources" / "app_icon.ico",
        sizes=[(s, s) for s in sizes],
    )

    linux = ROOT / "linux" / "runner" / "resources"
    linux.mkdir(exist_ok=True)
    logo.resize((256, 256), Image.LANCZOS).save(linux / "app_icon.png")


if __name__ == "__main__":
    main()
