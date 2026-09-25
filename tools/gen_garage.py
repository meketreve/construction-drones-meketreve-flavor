"""Draws the drone garage: a masonry building in the game's own palette, 3x3 tiles.

The antenna on the roof is not drawn here, the mod borrows the roboport one from the base game.
Run this from the mod root to overwrite the sprites in data/entities/graphics/.
"""
import math
import random
from PIL import Image, ImageDraw, ImageFilter

OUT = "data/entities/graphics/"

SIZE = 256
TILE = 64                      # high resolution, the sprite is drawn at half scale
FOOT = 3 * TILE                # a three by three footprint
CENTER = (128, 160)            # where the entity position falls on the canvas
WALL_H = 86                    # how tall the brick wall stands
ROOF_H = 118                   # the roof is foreshortened, the game looks at buildings from an angle

CONCRETE = (140, 137, 127)
CONCRETE_LIGHT = (176, 172, 161)
CONCRETE_DARK = (88, 85, 78)
CONCRETE_DEEP = (58, 56, 51)
BRICK = (152, 112, 92)
BRICK_DARK = (102, 72, 58)
MORTAR = (112, 106, 96)
METAL = (122, 126, 132)
METAL_DARK = (74, 78, 84)
HAZARD = (214, 163, 32)
ACCENT = (86, 200, 230)

random.seed(7)


def footprint():
    cx, cy = CENTER
    return [cx - FOOT / 2, cy - FOOT / 2, cx + FOOT / 2, cy + FOOT / 2]


def brick_wall(draw, box, rows=7):
    """Masonry: staggered courses, each brick shaded a little differently."""
    x0, y0, x1, y1 = box
    draw.rectangle(box, fill=MORTAR)
    height = (y1 - y0) / rows
    for row in range(rows):
        top = y0 + row * height
        bottom = top + height - 2
        offset = 0 if row % 2 == 0 else -18
        x = x0 + offset
        while x < x1:
            bx0, bx1 = max(x0, x + 2), min(x1, x + 34)
            if bx1 - bx0 > 3:
                shade = random.randint(-14, 14)
                fill = tuple(max(0, min(255, c + shade)) for c in BRICK)
                draw.rectangle([bx0, top, bx1, bottom], fill=fill)
                draw.line([(bx0, top), (bx1, top)], fill=tuple(min(255, c + 22) for c in fill))
                draw.line([(bx0, bottom), (bx1, bottom)], fill=BRICK_DARK)
            x += 36


def roof_slab(draw, box):
    x0, y0, x1, y1 = box
    draw.rectangle(box, fill=CONCRETE)
    # panel seams
    for i in range(1, 4):
        x = x0 + (x1 - x0) * i / 4
        draw.line([(x, y0 + 6), (x, y1 - 6)], fill=CONCRETE_DARK, width=2)
    for i in range(1, 3):
        y = y0 + (y1 - y0) * i / 3
        draw.line([(x0 + 6, y), (x1 - 6, y)], fill=CONCRETE_DARK, width=2)
    # speckle, so the concrete is not flat
    for _ in range(900):
        x, y = random.uniform(x0 + 2, x1 - 2), random.uniform(y0 + 2, y1 - 2)
        shade = random.randint(-10, 12)
        draw.point((x, y), fill=tuple(max(0, min(255, c + shade)) for c in CONCRETE))
    # parapet: a raised lip all around, lit from the top left
    draw.rectangle(box, outline=CONCRETE_DEEP, width=5)
    draw.rectangle([x0 + 2, y0 + 2, x1 - 2, y1 - 2], outline=CONCRETE_LIGHT, width=2)
    draw.line([(x0 + 3, y1 - 3), (x1 - 3, y1 - 3)], fill=CONCRETE_DARK, width=3)
    draw.line([(x1 - 3, y0 + 3), (x1 - 3, y1 - 3)], fill=CONCRETE_DARK, width=3)


def rivets(draw, box, step=22):
    x0, y0, x1, y1 = box
    for x in range(int(x0) + 10, int(x1) - 6, step):
        for y in (y0 + 8, y1 - 8):
            draw.ellipse([x - 2, y - 2, x + 2, y + 2], fill=CONCRETE_LIGHT)
            draw.point((x, y - 1), fill=(210, 206, 198))


def garage_door(draw, box):
    """A roll up door: dark recess, slats, a metal frame and hazard paint on the threshold."""
    x0, y0, x1, y1 = box
    draw.rectangle([x0 - 4, y0 - 4, x1 + 4, y1], fill=METAL_DARK)
    draw.rectangle([x0 - 2, y0 - 2, x1 + 2, y1], fill=METAL)
    draw.rectangle(box, fill=(38, 40, 44))
    slat = 7
    y = y0 + 3
    while y < y1 - 4:
        draw.rectangle([x0 + 3, y, x1 - 3, y + slat - 2], fill=(64, 67, 72))
        draw.line([(x0 + 3, y), (x1 - 3, y)], fill=(88, 92, 98))
        y += slat
    # the opening at the bottom, where the drones come out
    draw.rectangle([x0 + 3, y1 - 12, x1 - 3, y1], fill=(24, 25, 28))
    draw.line([(x0 + 3, y1 - 12), (x1 - 3, y1 - 12)], fill=(12, 13, 15), width=2)
    for i in range(3):
        lx = x0 + 14 + i * ((x1 - x0 - 28) / 2)
        draw.ellipse([lx - 3, y1 - 9, lx + 3, y1 - 5], fill=ACCENT)


def hazard_strip(draw, box):
    x0, y0, x1, y1 = box
    draw.rectangle(box, fill=HAZARD)
    for x in range(int(x0) - 20, int(x1) + 20, 16):
        draw.polygon([(x, y1), (x + 8, y1), (x + 8 + 10, y0), (x + 10, y0)], fill=(38, 34, 28))
    draw.rectangle(box, outline=(70, 56, 20))


def make_base():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    fx0, fy0, fx1, fy1 = footprint()
    # the roof sits above the wall and is squashed, the wall below it is what the player mostly sees
    roof = [fx0, fy1 - WALL_H - ROOF_H, fx1, fy1 - WALL_H]

    # shadow, thrown to the lower right like every building in the game
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rectangle([fx0 + 12, roof[1] + 16, fx1 + 16, fy1 + 4], fill=(0, 0, 0, 110))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(8)))

    d = ImageDraw.Draw(img)

    # front wall, from the roof line down to the bottom of the footprint
    wall = [fx0, roof[3], fx1, fy1]
    brick_wall(d, wall)
    d.rectangle(wall, outline=CONCRETE_DEEP, width=3)

    # concrete pillars at the corners of the wall
    for x in (fx0, fx1 - 16):
        d.rectangle([x, roof[3], x + 16, fy1], fill=CONCRETE)
        d.line([(x + 1, roof[3]), (x + 1, fy1)], fill=CONCRETE_LIGHT, width=2)
        d.line([(x + 15, roof[3]), (x + 15, fy1)], fill=CONCRETE_DARK, width=2)

    door_w, door_h = 92, WALL_H - 24
    door = [CENTER[0] - door_w / 2, fy1 - door_h - 6, CENTER[0] + door_w / 2, fy1 - 6]
    garage_door(d, door)
    hazard_strip(d, [fx0 + 18, fy1 - 8, fx1 - 18, fy1 - 1])

    # the roof overhangs a little, so the top of the wall sits in its shadow
    shade = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(shade).rectangle([fx0, roof[3], fx1, roof[3] + 16], fill=(0, 0, 0, 120))
    img.alpha_composite(shade.filter(ImageFilter.GaussianBlur(5)))

    # roof slab on top of the wall
    roof_slab(d, roof)
    rivets(d, roof)

    # a vent box and a crate, so the roof is not empty
    d.rectangle([roof[0] + 14, roof[1] + 14, roof[0] + 52, roof[1] + 40], fill=CONCRETE_DARK)
    d.rectangle([roof[0] + 18, roof[1] + 18, roof[0] + 48, roof[1] + 36], fill=METAL)
    for i in range(3):
        y = roof[1] + 21 + i * 5
        d.line([(roof[0] + 20, y), (roof[0] + 46, y)], fill=METAL_DARK)

    d.rectangle([roof[2] - 54, roof[3] - 34, roof[2] - 18, roof[3] - 12], fill=CONCRETE_DARK)
    d.rectangle([roof[2] - 50, roof[3] - 30, roof[2] - 22, roof[3] - 16], fill=CONCRETE_LIGHT)

    # the mount the antenna stands on, in the middle of the roof
    mx, my = CENTER[0], roof[1] + (roof[3] - roof[1]) * 0.62
    d.rectangle([mx - 26, my - 16, mx + 26, my + 18], fill=CONCRETE_DARK)
    d.rectangle([mx - 22, my - 12, mx + 22, my + 14], fill=CONCRETE)
    d.rectangle([mx - 22, my - 12, mx + 22, my - 6], fill=CONCRETE_LIGHT)
    for i in range(4):
        lx = mx - 18 + i * 12
        d.ellipse([lx - 2, my + 6, lx + 2, my + 10], fill=ACCENT)

    img.save(OUT + "drone_garage_base.png")
    return img


def make_icon(base):
    icon = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    crop = base.crop((28, 46, 228, 246)).resize((240, 240), Image.LANCZOS)
    icon.alpha_composite(crop, (8, 8))
    icon.resize((64, 64), Image.LANCZOS).save(OUT + "drone_garage_icon.png")


base = make_base()
make_icon(base)
print("ok")
