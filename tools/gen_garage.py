"""Generates the drone garage sprites: a 3x3 platform plus a rotating antenna animation."""
import math
from PIL import Image, ImageDraw, ImageFilter

OUT = "/mnt/SSD/git-projeto/factorio_construction_drones/Construction_Drones/data/entities/graphics/"

STEEL_DARK = (52, 56, 62)
STEEL = (92, 98, 106)
STEEL_LIGHT = (140, 148, 158)
STEEL_HIGH = (186, 194, 202)
RUST = (104, 84, 66)
ACCENT = (86, 200, 230)
ACCENT_DIM = (44, 120, 148)

BASE_SIZE = 256          # canvas of the static platform, high res (64 px per tile)
FOOT = 192               # 3 tiles
CENTER = (128, 156)      # where the structure sits on the canvas


def bevel_polygon(draw, points, fill, light, dark, width=3):
    draw.polygon(points, fill=fill)
    n = len(points)
    for i in range(n):
        a, b = points[i], points[(i + 1) % n]
        # edges facing up/left catch the light
        up = (a[1] + b[1]) / 2 < sum(p[1] for p in points) / n
        draw.line([a, b], fill=light if up else dark, width=width)


def iso_ellipse(draw, cx, cy, rx, ry, **kw):
    draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], **kw)


def draw_leg(draw, cx, cy, dx, dy, length, width):
    """A short strut under the deck edge, with a foot pad on the ground."""
    ex, ey = cx + dx * length, cy + dy * length * 0.55
    draw.line([(cx, cy), (ex, ey)], fill=(34, 37, 42), width=width + 3)
    draw.line([(cx, cy), (ex, ey)], fill=(76, 82, 90), width=width)
    iso_ellipse(draw, ex, ey + 2, width * 1.5, width * 0.7, fill=(30, 33, 37))
    iso_ellipse(draw, ex, ey + 1, width * 1.2, width * 0.5, fill=(88, 94, 102))


def octagon(cx, cy, rx, ry):
    pts = []
    for i in range(8):
        a = math.pi / 8 + i * math.pi / 4
        pts.append((cx + rx * math.cos(a), cy + ry * math.sin(a)))
    return pts


def make_base():
    img = Image.new("RGBA", (BASE_SIZE, BASE_SIZE), (0, 0, 0, 0))
    cx, cy = CENTER
    rx, ry = FOOT * 0.46, FOOT * 0.25
    deck = octagon(cx, cy, rx, ry)
    wall_h = 18

    # soft ground shadow
    shadow = Image.new("RGBA", (BASE_SIZE, BASE_SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).polygon([(x + 6, y + wall_h + 4) for x, y in deck], fill=(0, 0, 0, 110))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(9)))

    d = ImageDraw.Draw(img)

    # side wall: the lower silhouette of the deck, extruded down
    lower = [p for p in deck if p[1] >= cy - 1]
    lower.sort(key=lambda p: p[0])
    wall = [(x, y + wall_h) for x, y in reversed(lower)]
    d.polygon(lower + wall, fill=(40, 43, 48))
    for x, y in lower[1:-1]:
        d.line([(x, y), (x, y + wall_h)], fill=(52, 56, 62), width=2)

    # deck plate
    d.polygon(deck, fill=STEEL)
    d.line(deck + [deck[0]], fill=STEEL_DARK, width=3)
    for i in range(4):
        a, b = deck[i], deck[i + 1]
        d.line([a, b], fill=STEEL_HIGH, width=2)

    # plating grooves
    for i in range(8):
        a = math.pi / 8 + i * math.pi / 4
        d.line([(cx + rx * 0.34 * math.cos(a), cy + ry * 0.34 * math.sin(a)),
                (cx + rx * 0.94 * math.cos(a), cy + ry * 0.94 * math.sin(a))],
               fill=(72, 77, 84), width=2)
    d.polygon(octagon(cx, cy, rx * 0.34, ry * 0.34), fill=(78, 84, 92), outline=(58, 62, 68))

    # drone bays on the front wall
    for ox in (-52, 0, 52):
        x0, y0 = cx + ox - 19, cy + ry * 0.62
        d.rounded_rectangle([x0, y0, x0 + 38, y0 + 21], radius=4, fill=(34, 37, 42))
        d.rounded_rectangle([x0 + 3, y0 + 3, x0 + 35, y0 + 13], radius=3, fill=(84, 90, 98))
        d.line([(x0 + 5, y0 + 17), (x0 + 33, y0 + 17)], fill=ACCENT_DIM, width=2)

    # short struts holding the deck up, at the two front corners
    for dx in (-1, 1):
        draw_leg(d, cx + dx * rx * 0.80, cy + ry * 0.36 + wall_h, dx * 0.5, 1, 26, 8)

    # central hub
    iso_ellipse(d, cx, cy - 14, 36, 21, fill=(44, 47, 52))
    iso_ellipse(d, cx, cy - 17, 31, 18, fill=STEEL)
    iso_ellipse(d, cx, cy - 19, 23, 13, fill=STEEL_LIGHT)
    iso_ellipse(d, cx, cy - 20, 16, 9, fill=(64, 69, 76))
    for i in range(6):
        a = i * math.pi / 3 + 0.3
        iso_ellipse(d, cx + 29 * math.cos(a), cy - 16 + 16 * math.sin(a), 3, 2, fill=ACCENT)

    # mast
    d.rectangle([cx - 8, cy - 68, cx + 8, cy - 18], fill=(42, 45, 50))
    d.rectangle([cx - 6, cy - 68, cx + 3, cy - 18], fill=STEEL)
    d.rectangle([cx - 6, cy - 68, cx - 3, cy - 18], fill=STEEL_LIGHT)
    for y in range(int(cy) - 70, int(cy) - 22, 13):
        d.line([(cx - 8, y), (cx + 8, y)], fill=(38, 41, 46), width=2)
    iso_ellipse(d, cx, cy - 68, 10, 6, fill=STEEL_LIGHT)

    img.save(OUT + "drone_garage_base.png")
    return img


FRAMES = 24
FRAME = 160
FCENTER = (80, 118)      # the mast top inside a frame


def draw_dish(d, cx, cy, angle):
    """A dish on a yoke, spinning around the mast. Facing the camera it shows its inside."""
    facing = math.cos(angle)          # 1 = towards the viewer, -1 = away
    side = math.sin(angle)
    reach = 26

    # yoke arm from the mast towards the dish
    ax, ay = cx + side * reach * 0.55, cy - 4 + facing * 6
    d.line([(cx, cy), (ax, ay)], fill=STEEL_DARK, width=7)
    d.line([(cx, cy - 1), (ax, ay - 1)], fill=STEEL, width=4)

    rx = 30 * (0.30 + 0.70 * abs(side)) if False else 30
    # the dish flattens when it points at or away from the camera is wrong for a horizontal
    # spin: it flattens when seen edge on, which happens at side == +-1
    rx = 30 * (0.34 + 0.66 * abs(facing))
    ry = 21

    box = [ax - rx, ay - ry, ax + rx, ay + ry]
    if facing >= 0:
        # inside of the dish, lit
        d.ellipse(box, fill=(70, 76, 84), outline=STEEL_DARK, width=3)
        inner = [ax - rx * 0.72, ay - ry * 0.72, ax + rx * 0.72, ay + ry * 0.72]
        d.ellipse(inner, fill=(96, 104, 114), outline=(58, 63, 70), width=2)
        d.ellipse([ax - rx * 0.3, ay - ry * 0.3, ax + rx * 0.3, ay + ry * 0.3],
                  fill=ACCENT_DIM)
        # feed horn on struts, in front of the dish
        fx, fy = ax + side * 4, ay + 13
        d.line([(ax - rx * 0.6, ay), (fx, fy)], fill=STEEL_DARK, width=2)
        d.line([(ax + rx * 0.6, ay), (fx, fy)], fill=STEEL_DARK, width=2)
        d.ellipse([fx - 4, fy - 4, fx + 4, fy + 4], fill=STEEL_LIGHT, outline=STEEL_DARK)
    else:
        # back of the dish, a plain shell with ribs
        d.ellipse(box, fill=STEEL, outline=STEEL_DARK, width=3)
        d.ellipse([ax - rx * 0.55, ay - ry * 0.55, ax + rx * 0.55, ay + ry * 0.55],
                  fill=(74, 80, 88), outline=(58, 63, 70), width=2)
        d.line([(ax - rx, ay), (ax + rx, ay)], fill=(64, 69, 76), width=2)

    # a blinking tip light, brighter when the dish faces us
    glow = int(120 + 135 * max(0.0, facing))
    d.ellipse([ax - 3, ay - ry - 6, ax + 3, ay - ry], fill=(glow, 60, 60))


def make_animation():
    cols, rows = 6, 4
    sheet = Image.new("RGBA", (FRAME * cols, FRAME * rows), (0, 0, 0, 0))
    for i in range(FRAMES):
        frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        d = ImageDraw.Draw(frame)
        angle = 2 * math.pi * i / FRAMES
        cx, cy = FCENTER
        # bearing on top of the mast
        d.ellipse([cx - 11, cy - 7, cx + 11, cy + 7], fill=STEEL_DARK)
        d.ellipse([cx - 8, cy - 6, cx + 8, cy + 3], fill=STEEL)
        draw_dish(d, cx, cy - 4, angle)
        sheet.alpha_composite(frame, (FRAME * (i % cols), FRAME * (i // cols)))
    sheet.save(OUT + "drone_garage_antenna.png")
    return sheet


def make_icon(base):
    icon = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    shot = base.crop((16, 40, 240, 264)).resize((236, 236), Image.LANCZOS)
    icon.alpha_composite(shot, (10, 10))
    d = ImageDraw.Draw(icon)
    draw_dish(d, 128, 92, math.pi * 0.15)
    icon.resize((64, 64), Image.LANCZOS).save(OUT + "drone_garage_icon.png")


base = make_base()
anim = make_animation()
make_icon(base)
print("ok")
