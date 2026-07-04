#!/usr/bin/env python3
import math
import os
import struct
import zlib


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RESOURCES = os.path.join(ROOT, "Resources")
ICONSET = os.path.join(RESOURCES, "AppIcon.iconset")


def clamp(v, lo=0, hi=255):
    return max(lo, min(hi, int(round(v))))


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


def distance_to_segment(px, py, ax, ay, bx, by):
    vx = bx - ax
    vy = by - ay
    wx = px - ax
    wy = py - ay
    length2 = vx * vx + vy * vy
    if length2 == 0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, (wx * vx + wy * vy) / length2))
    cx = ax + t * vx
    cy = ay + t * vy
    return math.hypot(px - cx, py - cy)


def rounded_rect_alpha(x, y, w, h, r):
    dx = max(r - x, 0, x - (w - r))
    dy = max(r - y, 0, y - (h - r))
    if dx == 0 and dy == 0:
        return 255
    dist = math.hypot(dx, dy)
    return clamp(255 * (1 - smoothstep(r - 1.5, r + 1.5, dist)))


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
        row = pixels[y * width : (y + 1) * width]
        for r, g, b, a in row:
            raw.extend([r, g, b, a])

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
        f.write(chunk(b"IEND", b""))


def write_icns(path, entries):
    chunks = []
    for kind, png_path in entries:
        with open(png_path, "rb") as f:
            data = f.read()
        chunk_size = 8 + len(data)
        chunks.append(kind.encode("ascii") + struct.pack(">I", chunk_size) + data)

    total_size = 8 + sum(len(chunk) for chunk in chunks)
    with open(path, "wb") as f:
        f.write(b"icns")
        f.write(struct.pack(">I", total_size))
        for chunk in chunks:
            f.write(chunk)


def draw_logo(size):
    w = h = size
    pixels = [(0, 0, 0, 0)] * (w * h)
    radius = size * 0.205

    for y in range(h):
        for x in range(w):
            a = rounded_rect_alpha(x + 0.5, y + 0.5, w, h, radius)
            if a == 0:
                continue
            nx = x / (w - 1)
            ny = y / (h - 1)
            left = (6, 48, 146)
            right = (0, 198, 194)
            glow = max(0.0, 1.0 - math.hypot(nx - 0.58, ny - 0.78) / 0.38)
            r = left[0] * (1 - nx) + right[0] * nx + 12 * glow
            g = left[1] * (1 - nx) + right[1] * nx + 44 * glow
            b = left[2] * (1 - nx) + right[2] * nx + 38 * glow
            pixels[y * w + x] = (clamp(r), clamp(g), clamp(b), a)

    def paint_capsule(ax, ay, bx, by, width, color):
        half = width / 2
        for y in range(h):
            for x in range(w):
                d = distance_to_segment(x + 0.5, y + 0.5, ax, ay, bx, by)
                a = clamp(color[3] * (1 - smoothstep(half - 2, half + 2, d)))
                if a:
                    idx = y * w + x
                    pixels[idx] = blend(pixels[idx], (color[0], color[1], color[2], a))

    # Soft shadow and white V/remote body.
    paint_capsule(size * 0.30, size * 0.22, size * 0.50, size * 0.78, size * 0.16, (0, 22, 80, 45))
    paint_capsule(size * 0.76, size * 0.22, size * 0.50, size * 0.78, size * 0.16, (0, 22, 80, 40))
    paint_capsule(size * 0.30, size * 0.22, size * 0.50, size * 0.78, size * 0.145, (255, 255, 255, 250))
    paint_capsule(size * 0.76, size * 0.22, size * 0.50, size * 0.78, size * 0.145, (255, 255, 255, 250))

    # Voice bars.
    for i, height_factor in enumerate([0.10, 0.18, 0.28, 0.18, 0.10]):
        cx = size * (0.40 + i * 0.05)
        cy = size * 0.34
        bar_h = size * height_factor
        paint_capsule(cx, cy - bar_h / 2, cx, cy + bar_h / 2, size * 0.018, (96, 235, 255, 230))

    # Remote microphone circle and button.
    cx, cy, rr = size * 0.30, size * 0.33, size * 0.075
    for y in range(h):
        for x in range(w):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            a = clamp(255 * (1 - smoothstep(rr - 2, rr + 2, d)))
            if a:
                pixels[y * w + x] = blend(pixels[y * w + x], (8, 73, 158, a))

    paint_capsule(size * 0.285, size * 0.31, size * 0.285, size * 0.35, size * 0.024, (255, 255, 255, 245))
    paint_capsule(size * 0.265, size * 0.365, size * 0.305, size * 0.365, size * 0.012, (255, 255, 255, 245))
    paint_capsule(size * 0.285, size * 0.365, size * 0.285, size * 0.39, size * 0.010, (255, 255, 255, 245))
    paint_capsule(size * 0.31, size * 0.52, size * 0.31, size * 0.56, size * 0.050, (0, 142, 235, 240))

    return pixels


def downsample(src, src_size, dst_size):
    scale = src_size // dst_size
    out = []
    for y in range(dst_size):
        for x in range(dst_size):
            r = g = b = a = 0
            count = 0
            for yy in range(scale):
                for xx in range(scale):
                    pr, pg, pb, pa = src[(y * scale + yy) * src_size + (x * scale + xx)]
                    r += pr
                    g += pg
                    b += pb
                    a += pa
                    count += 1
            out.append((clamp(r / count), clamp(g / count), clamp(b / count), clamp(a / count)))
    return out


def draw_menu_icon(size):
    pixels = [(0, 0, 0, 0)] * (size * size)

    def paint(ax, ay, bx, by, width, alpha=255):
        half = width / 2
        for y in range(size):
            for x in range(size):
                d = distance_to_segment(x + 0.5, y + 0.5, ax, ay, bx, by)
                a = clamp(alpha * (1 - smoothstep(half - 1, half + 1, d)))
                if a:
                    pixels[y * size + x] = blend(pixels[y * size + x], (0, 0, 0, a))

    paint(size * 0.24, size * 0.20, size * 0.49, size * 0.80, size * 0.14)
    paint(size * 0.76, size * 0.20, size * 0.49, size * 0.80, size * 0.14)
    for i, hf in enumerate([0.12, 0.22, 0.32]):
        x = size * (0.42 + i * 0.08)
        paint(x, size * (0.42 - hf / 2), x, size * (0.42 + hf / 2), size * 0.055, 190)
    return pixels


def main():
    os.makedirs(RESOURCES, exist_ok=True)
    os.makedirs(ICONSET, exist_ok=True)

    base_size = 1024
    base = draw_logo(base_size)
    write_png(os.path.join(RESOURCES, "Logo.png"), base_size, base_size, base)

    icon_specs = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    for filename, size in icon_specs.items():
        pixels = base if size == base_size else downsample(base, base_size, size)
        write_png(os.path.join(ICONSET, filename), size, size, pixels)

    menu = draw_menu_icon(64)
    write_png(os.path.join(RESOURCES, "MenuIconTemplate.png"), 64, 64, menu)

    write_icns(
        os.path.join(RESOURCES, "AppIcon.icns"),
        [
            ("icp4", os.path.join(ICONSET, "icon_16x16.png")),
            ("icp5", os.path.join(ICONSET, "icon_32x32.png")),
            ("icp6", os.path.join(ICONSET, "icon_32x32@2x.png")),
            ("ic07", os.path.join(ICONSET, "icon_128x128.png")),
            ("ic08", os.path.join(ICONSET, "icon_256x256.png")),
            ("ic09", os.path.join(ICONSET, "icon_512x512.png")),
            ("ic10", os.path.join(ICONSET, "icon_512x512@2x.png")),
        ],
    )


if __name__ == "__main__":
    main()
