"""Generates the 4Ma5zya app icon (open book + sound waves) without third-party libraries.

Outputs assets/icon/icon.png (full, 1024px) and assets/icon/icon_foreground.png
(transparent, for Android adaptive icons). Usage: python3 tool/make_icon.py
"""
import math
import struct
import zlib

SIZE = 1024
SS = 2  # supersampling per axis

TEAL_TOP = (20, 122, 115)
TEAL_BOTTOM = (11, 74, 74)
WHITE = (255, 255, 255)
GOLD = (214, 172, 46)


def in_quad(x, y, pts):
    sign = None
    for i in range(4):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % 4]
        c = (x2 - x1) * (y - y1) - (y2 - y1) * (x - x1)
        s = c >= 0
        if sign is None:
            sign = s
        elif s != sign:
            return False
    return True


def glyph(x, y, scale):
    """Returns colour of the book/wave glyph at normalised (x, y), or None. scale shrinks around the centre."""
    x = 0.5 + (x - 0.5) / scale
    y = 0.5 + (y - 0.5) / scale
    left = [(0.17, 0.50), (0.475, 0.565), (0.475, 0.82), (0.17, 0.755)]
    right = [(0.525, 0.565), (0.83, 0.50), (0.83, 0.755), (0.525, 0.82)]
    if in_quad(x, y, left) or in_quad(x, y, right):
        return WHITE
    cx, cy = 0.5, 0.50
    dx, dy = x - cx, y - cy
    r = math.hypot(dx, dy)
    if dy < 0:
        ang = math.degrees(math.atan2(dx, -dy))
        if abs(ang) <= 42:
            for radius in (0.12, 0.20, 0.28):
                if abs(r - radius) <= 0.022:
                    return GOLD
    return None


def render(full):
    rows = []
    for py in range(SIZE):
        row = bytearray([0])
        for px in range(SIZE):
            acc = [0.0, 0.0, 0.0, 0.0]
            for sy in range(SS):
                for sx in range(SS):
                    x = (px + (sx + 0.5) / SS) / SIZE
                    y = (py + (sy + 0.5) / SS) / SIZE
                    g = glyph(x, y, 1.0 if full else 0.62)
                    if full:
                        t = y
                        bg = tuple(TEAL_TOP[i] * (1 - t) + TEAL_BOTTOM[i] * t for i in range(3))
                        c = g or bg
                        a = 255
                    else:
                        c = g or (0, 0, 0)
                        a = 255 if g else 0
                    acc[0] += c[0] * a
                    acc[1] += c[1] * a
                    acc[2] += c[2] * a
                    acc[3] += a
            n = SS * SS
            alpha = acc[3] / n
            if alpha > 0:
                row += bytes((int(acc[0] / acc[3]), int(acc[1] / acc[3]), int(acc[2] / acc[3]), int(alpha)))
            else:
                row += b"\x00\x00\x00\x00"
        rows.append(bytes(row))
    return b"".join(rows)


def write_png(path, raw):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


if __name__ == "__main__":
    write_png("assets/icon/icon.png", render(True))
    write_png("assets/icon/icon_foreground.png", render(False))
    print("icons written")
