"""Generate AetherNav Edge launcher icons: indigo->teal diagonal gradient with a
white navigation arrow. Produces the legacy square icon plus adaptive-icon
background and foreground layers. Run once via flutter_launcher_icons."""
from PIL import Image, ImageDraw

INDIGO = (79, 70, 229)   # #4F46E5
TEAL = (13, 148, 136)    # #0D9488
SIZE = 1024


def gradient(size=SIZE):
    # Compute a diagonal lerp on a small canvas, then upscale smoothly (no banding).
    small = 64
    img = Image.new("RGB", (small, small))
    px = img.load()
    for y in range(small):
        for x in range(small):
            t = (x + y) / (2 * (small - 1))
            px[x, y] = (
                round(INDIGO[0] + (TEAL[0] - INDIGO[0]) * t),
                round(INDIGO[1] + (TEAL[1] - INDIGO[1]) * t),
                round(INDIGO[2] + (TEAL[2] - INDIGO[2]) * t),
            )
    return img.resize((size, size), Image.BICUBIC)


def arrow_points(cx, cy, scale):
    # Classic navigation arrowhead pointing up: tip, base-right, notch, base-left.
    pts = [(0, -300), (250, 290), (0, 170), (-250, 290)]
    return [(cx + x * scale, cy + y * scale) for x, y in pts]


def draw_arrow(img, scale):
    d = ImageDraw.Draw(img)
    d.polygon(arrow_points(SIZE / 2, SIZE / 2, scale), fill=(255, 255, 255, 255))


# Legacy square icon: gradient + arrow.
legacy = gradient().convert("RGBA")
draw_arrow(legacy, 1.0)
legacy.convert("RGB").save("assets/icon/app_icon.png")

# Adaptive background: gradient only.
gradient().save("assets/icon/app_icon_background.png")

# Adaptive foreground: arrow on transparent, shrunk into the safe zone.
fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw_arrow(fg, 0.62)
fg.save("assets/icon/app_icon_foreground.png")

print("wrote app_icon.png, app_icon_background.png, app_icon_foreground.png")
