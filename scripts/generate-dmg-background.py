#!/usr/bin/env python3
import math
import os
import struct
import zlib


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RESOURCES = os.path.join(ROOT, "Resources")


def clamp(value, lo=0, hi=255):
    return max(lo, min(hi, int(round(value))))


def smoothstep(edge0, edge1, x):
    if edge0 == edge1:
        return 1.0 if x >= edge1 else 0.0
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)


def blend(dst, src):
    sr, sg, sb, sa = src
    if sa <= 0:
        return dst
    dr, dg, db, da = dst
    a = sa / 255.0
    ia = 1.0 - a
    return (
        clamp(sr * a + dr * ia),
        clamp(sg * a + dg * ia),
        clamp(sb * a + db * ia),
        clamp(255 * (a + da / 255.0 * ia)),
    )


def write_png(path, width, height, pixels):
    def chunk(tag, data):
        payload = tag + data
        return (
            struct.pack(">I", len(data))
            + payload
            + struct.pack(">I", zlib.crc32(payload) & 0xFFFFFFFF)
        )

    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for r, g, b, a in pixels[y * width : (y + 1) * width]:
            raw.extend([r, g, b, a])

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
        f.write(chunk(b"IEND", b""))


def draw_text_block(pixels, width, height, x, y, text, scale, color):
    glyphs = {
        "D": ["1110", "1001", "1001", "1001", "1001", "1001", "1110"],
        "R": ["1110", "1001", "1001", "1110", "1010", "1001", "1001"],
        "A": ["0110", "1001", "1001", "1111", "1001", "1001", "1001"],
        "G": ["0111", "1000", "1000", "1011", "1001", "1001", "0111"],
        "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
        "O": ["0110", "1001", "1001", "1001", "1001", "1001", "0110"],
        "I": ["111", "010", "010", "010", "010", "010", "111"],
        "N": ["1001", "1101", "1101", "1011", "1011", "1001", "1001"],
        "S": ["0111", "1000", "1000", "0110", "0001", "0001", "1110"],
        "L": ["1000", "1000", "1000", "1000", "1000", "1000", "1111"],
        "V": ["1001", "1001", "1001", "1001", "1001", "0110", "0110"],
        "B": ["1110", "1001", "1001", "1110", "1001", "1001", "1110"],
        "E": ["1111", "1000", "1000", "1110", "1000", "1000", "1111"],
        "C": ["0111", "1000", "1000", "1000", "1000", "1000", "0111"],
        " ": ["0", "0", "0", "0", "0", "0", "0"],
    }
    cursor = x
    for ch in text:
        glyph = glyphs.get(ch.upper(), glyphs[" "])
        for gy, row in enumerate(glyph):
            for gx, cell in enumerate(row):
                if cell == "1":
                    for yy in range(scale):
                        for xx in range(scale):
                            px = cursor + gx * scale + xx
                            py = y + gy * scale + yy
                            if 0 <= px < width and 0 <= py < height:
                                idx = py * width + px
                                pixels[idx] = blend(pixels[idx], color)
        cursor += (len(glyph[0]) + 1) * scale


def draw_background(width=920, height=520):
    pixels = []
    for y in range(height):
        for x in range(width):
            nx = x / (width - 1)
            ny = y / (height - 1)
            glow1 = max(0.0, 1.0 - math.hypot(nx - 0.24, ny - 0.25) / 0.42)
            glow2 = max(0.0, 1.0 - math.hypot(nx - 0.82, ny - 0.72) / 0.50)
            r = 245 + 8 * glow1 - 5 * glow2
            g = 248 + 7 * glow1 + 2 * glow2
            b = 250 + 6 * glow1 + 6 * glow2
            pixels.append((clamp(r), clamp(g), clamp(b), 255))

    # Subtle installation lanes behind the icons.
    for y in range(height):
        for x in range(width):
            idx = y * width + x
            for cx, cy in [(250, 260), (670, 260)]:
                dist = math.hypot((x - cx) / 1.25, y - cy)
                alpha = clamp(42 * (1 - smoothstep(130, 240, dist)))
                pixels[idx] = blend(pixels[idx], (255, 255, 255, alpha))

    # Arrow rail.
    for y in range(height):
        for x in range(width):
            idx = y * width + x
            dist_line = abs(y - 258)
            if 355 <= x <= 565:
                alpha = clamp(120 * (1 - smoothstep(2, 7, dist_line)))
                pixels[idx] = blend(pixels[idx], (0, 170, 190, alpha))

            # Arrow head.
            dx = x - 572
            dy = y - 258
            if -28 <= dx <= 0 and abs(dy) <= -dx * 0.62 + 3:
                pixels[idx] = blend(pixels[idx], (0, 170, 190, 180))

    # Soft arrow highlight.
    for y in range(height):
        for x in range(width):
            idx = y * width + x
            glow = max(0.0, 1.0 - math.hypot((x - 470) / 210, (y - 258) / 90))
            pixels[idx] = blend(pixels[idx], (0, 180, 190, clamp(26 * glow)))

    draw_text_block(pixels, width, height, 371, 198, "DRAG TO INSTALL", 4, (24, 40, 52, 210))
    draw_text_block(pixels, width, height, 368, 318, "VIBE CODING", 3, (70, 84, 96, 155))

    return pixels


def main():
    os.makedirs(RESOURCES, exist_ok=True)
    write_png(os.path.join(RESOURCES, "DmgBackground.png"), 920, 520, draw_background())


if __name__ == "__main__":
    main()
