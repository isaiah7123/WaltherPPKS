"""Build the .380 ACP ammo box art (CAP-9) from vanilla Project Zomboid 9mm box art.

Outputs (in the mod):
  42/media/textures/WorldItems/BoxOfRounds380ACP.png  (64x128, same layout as BoxOfRounds9MM.png)
  42/media/textures/Item_PPKS380Box.png               (32x32 icon, edited from vanilla Item_HandgunAmmoBox)
  42/icon.png, 42/poster.png, workshop/WaltherPPKS/preview.png (listing images composed from the two icons;
  run tools/build_model.py first so the gun icon exists)

The vanilla icon is pulled from media/texturepacks/UI.pack, so no Blender render is needed.
Edited vanilla art stays inside this free mod that requires the base game (PZ Modding Policy).

Usage:  python tools/build_box_art.py [--game "C:/.../ProjectZomboid"]
Requires Pillow.
"""
import argparse
import colorsys
import io
import os
import struct
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(ROOT, "workshop", "WaltherPPKS", "Contents", "mods", "WaltherPPKS", "42", "media", "textures")
DEFAULT_GAME = r"C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid"

# Box body colour: vanilla 9mm box is red; .380 box becomes dark green so it reads differently at a glance.
TARGET_HUE = 135 / 360.0
TARGET_SAT_SCALE = 0.75
TEXT_COLOR = (20, 16, 14)


def read_pack_sprite(pack_path, sprite_name):
    """Return (image cropped to frame, (x, y, w, h, ox, oy, fw, fh)) for one sprite of a PZ .pack file."""
    d = open(pack_path, "rb").read()
    p = 0

    def i32():
        nonlocal p
        v = struct.unpack_from("<i", d, p)[0]
        p += 4
        return v

    def s():
        nonlocal p
        n = i32()
        v = d[p:p + n].decode("latin1")
        p += n
        return v

    if d[:4] == b"PZPK":
        p = 8
    for _ in range(i32()):
        s()  # page name
        n = i32()
        i32()  # mask flag
        entries = [(s(),) + tuple(i32() for _ in range(8)) for _ in range(n)]
        if d[p:p + 4] != b"\x89PNG":
            raise RuntimeError("unexpected pack layout at %d" % p)
        q = p + 8
        while True:
            ln = struct.unpack_from(">I", d, q)[0]
            tag = d[q + 4:q + 8]
            q += 12 + ln
            if tag == b"IEND":
                break
        png = d[p:q]
        p = q
        if d[p:p + 4] == b"\xef\xbe\xad\xde":
            p += 4
        for e in entries:
            if e[0] == sprite_name:
                x, y, w, h, ox, oy, fw, fh = e[1:]
                sheet = Image.open(io.BytesIO(png)).convert("RGBA")
                frame = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
                frame.paste(sheet.crop((x, y, x + w, y + h)), (ox, oy))
                return frame
    raise KeyError(sprite_name)


def is_box_red(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    return (h < 0.06 or h > 0.85) and s > 0.18 and v > 0.05


def recolor_red(im):
    """Shift the red cardboard hue to the .380 green, keeping shading."""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            r, g, b = c[:3]
            if is_box_red(r, g, b):
                h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
                nr, ng, nb = colorsys.hsv_to_rgb(TARGET_HUE, s * TARGET_SAT_SCALE, v * 0.85)
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255)) + tuple(c[3:])
    return im


def find_font(size):
    for name in ("timesbd.ttf", "georgiab.ttf", "arialbd.ttf", "DejaVuSerif-Bold.ttf"):
        for base in (r"C:/Windows/Fonts", "/usr/share/fonts/truetype/dejavu", ""):
            path = os.path.join(base, name) if base else name
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def text_block(lines, box_w, box_h, color, ss=8):
    """Render lines of text supersampled, fitted to box (w,h) after a 90-degree CCW rotation.

    Vanilla box text reads bottom-to-top, so we lay text out horizontally in a (box_h x box_w)
    canvas and rotate it 90 degrees counter-clockwise.
    """
    W, H = box_h * ss, box_w * ss
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    size = H
    while size > 4:
        font = find_font(size)
        widths = [draw.textbbox((0, 0), t, font=font) for t in lines]
        tw = max(b[2] - b[0] for b in widths)
        line_h = max(b[3] - b[1] for b in widths)
        th = line_h * len(lines) + (len(lines) - 1) * size // 6
        if tw <= W * 0.95 and th <= H * 0.9:
            break
        size -= 2
    y = (H - th) // 2
    for t, b in zip(lines, widths):
        w = b[2] - b[0]
        draw.text(((W - w) // 2 - b[0], y - b[1]), t, font=font, fill=color)
        y += line_h + size // 6
    canvas = canvas.rotate(90, expand=True)
    return canvas.resize((box_w, box_h), Image.LANCZOS)


def build_texture(game, out_path):
    src = os.path.join(game, "media", "textures", "WorldItems", "BoxOfRounds9MM.png")
    im = Image.open(src).convert("RGBA")
    assert im.size == (64, 128), im.size
    # Layout of the vanilla 64x128 texture (pixels): blue label panel interior x6-35 y28-89;
    # pistol drawing x12-26 y32-54; "9MM ROUNDS" text x10-31 y41-86; side text x50-55 y30-87.
    label_blue = im.getpixel((8, 30))[:3]
    im = recolor_red(im)
    body = im.getpixel((40, 60))[:3]
    d = ImageDraw.Draw(im)
    # Front panel: keep the vanilla pistol drawing, erase "9MM ROUNDS", write ".380 ACP".
    d.rectangle((19, 40, 35, 55), fill=label_blue + (255,))
    d.rectangle((7, 56, 35, 89), fill=label_blue + (255,))
    im.alpha_composite(text_block([".380", "ACP"], 25, 32, TEXT_COLOR + (255,)), (9, 57))
    # Side strip: erase "9MM ROUNDS", write ".380 ACP".
    d.rectangle((47, 28, 59, 89), fill=body + (255,))
    im.alpha_composite(text_block([".380 ACP"], 9, 58, TEXT_COLOR + (255,)), (49, 30))
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    im.convert("RGB").save(out_path)
    print("wrote", out_path)


def build_icon(game, out_path):
    pack = os.path.join(game, "media", "texturepacks", "UI.pack")
    icon = read_pack_sprite(pack, "Item_HandgunAmmoBox")
    icon = recolor_red(icon)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    icon.save(out_path)
    print("wrote", out_path)


def build_listing_images():
    """Mod-list icon/poster and Workshop preview, composed from the gun and .380 box icons (no new art)."""
    gun_p = os.path.join(MOD, "Item_PPKS.png")
    box_p = os.path.join(MOD, "Item_PPKS380Box.png")
    if not os.path.exists(gun_p):
        print("skip listing images: run build_model.py first")
        return
    gun = Image.open(gun_p).convert("RGBA")
    box = Image.open(box_p).convert("RGBA")
    mod42 = os.path.dirname(os.path.dirname(MOD))
    gun.save(os.path.join(mod42, "icon.png"))
    poster = Image.new("RGBA", (256, 256), (46, 48, 44, 255))
    # gun top-left, box below-right of it, caption in its own strip at the bottom (no overlap)
    poster.alpha_composite(gun.resize((160, 160), Image.NEAREST), (8, 4))
    poster.alpha_composite(box.resize((80, 80), Image.NEAREST), (168, 124))
    d = ImageDraw.Draw(poster)
    d.text((12, 222), "Walther PPK/S  .380 ACP", font=find_font(18), fill=(235, 230, 220, 255))
    poster.save(os.path.join(mod42, "poster.png"))
    preview = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(mod42)))), "preview.png")
    poster.convert("RGB").save(preview)
    print("wrote icon.png, poster.png, preview.png")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--game", default=DEFAULT_GAME)
    a = ap.parse_args()
    build_texture(a.game, os.path.join(MOD, "WorldItems", "BoxOfRounds380ACP.png"))
    build_icon(a.game, os.path.join(MOD, "Item_PPKS380Box.png"))
    build_listing_images()


if __name__ == "__main__":
    sys.exit(main())
