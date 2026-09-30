#!/usr/bin/env python3
"""Render the 1024 App Icon to match Shared/BrandMark.swift."""

from PIL import Image, ImageDraw

SIZE = 1024
SCALE = 4
S = SIZE * SCALE
INK = (10, 10, 10)
FLARE = (255, 61, 171)
ACID = (216, 255, 60)
AURORA = (61, 255, 231)

w = float(S)
t = w * 0.22
arm = w * 0.72
origin = (w - arm) / 2
radius = t / 2

img = Image.new("RGB", (S, S), INK)
draw = ImageDraw.Draw(img)

vx0 = (w - t) / 2
draw.rounded_rectangle([vx0, origin, vx0 + t, origin + arm], radius=radius, fill=FLARE)
draw.rounded_rectangle([origin, (w - t) / 2, origin + arm, (w - t) / 2 + t], radius=radius, fill=FLARE)

points = [
    (0.14 * w, 0.70 * w),
    (0.34 * w, 0.56 * w),
    (0.50 * w, 0.62 * w),
    (0.70 * w, 0.36 * w),
    (0.88 * w, 0.20 * w),
]
draw.line(points, fill=ACID, width=int(w * 0.08), joint="curve")
dot = w * 0.048
for x, y in points:
    draw.ellipse([x - dot, y - dot, x + dot, y + dot], fill=AURORA)

out = img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
out.save("Assets.xcassets/AppIcon.appiconset/AppIcon.png")
print("wrote Assets.xcassets/AppIcon.appiconset/AppIcon.png")
