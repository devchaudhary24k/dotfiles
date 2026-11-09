#!/usr/bin/env python3
"""Turn the company logo SVG into terminal art for fastfetch.

    python3 assets/fastfetch/logo-anim.py "/path/to/Social PFP.svg" home/fastfetch/.config/fastfetch

Writes two files to the output folder:

  logo.txt   the still logo, in fastfetch's file-logo format ($1..$6 pick the
             colours set in config.jsonc)
  logo.loop  the idle animation `ff-logo` plays over the logo after fastfetch
             has printed: one cycle of frames (24-bit colour text, one line
             per logo row, frames separated by NUL bytes), played on repeat

The logo is drawn with quadrant block characters (2 x 2 "pixels" per cell),
so its slanted edges stay sharp. The SVG must be made of straight lines
(M, L, H, V, Z); a path that touches itself is split into separate shards.
"""

import math
import re
import sys
from pathlib import Path

# Layout. ROWS is the height of the logo in terminal rows; CELL_ASPECT is how
# much taller a cell is than wide (JetBrains Mono with Ghostty's line height).
ROWS = 12
CELL_ASPECT = 2.15
SAMPLES = 4  # per pixel side, for anti-aliased coverage

# Colours (Catppuccin Mocha greys into the logo's own #f2f2f2). The logo is
# shaded left to right, dark at the tail and white at the tip, like motion.
GRADIENT = ["#6c7086", "#7f849c", "#9399b2", "#bac2de", "#dfe3f2", "#f2f2f2"]
PULSE = ["#ffffff", "#f5f7ff", "#e6e9f5"]  # centre of the pulse outwards
SPARK = ["#ffffff", "#b4befe", "#7f849c"]  # bright, lavender, fading

# One cycle at FPS frames a second: the pulse runs tail to tip, the tip
# flares, then the logo rests. ff-logo skips repeated frames, so the rest
# costs nothing.
FPS = 12
PULSE_FRAMES = 20
FLARE_FRAMES = 6
REST_FRAMES = 34

QUADRANTS = " ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█"  # index = TL | TR<<1 | BL<<2 | BR<<3


def parse_path(svg_text):
    match = re.search(r'<path[^>]*\sd="([^"]+)"', svg_text)
    if not match:
        sys.exit("no <path d=...> found in the SVG")
    tokens = re.findall(r"[MmLlHhVvZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?", match.group(1))
    points, x, y, cmd, i = [], 0.0, 0.0, None, 0
    while i < len(tokens):
        tok = tokens[i]
        if tok.isalpha():
            cmd = tok
            i += 1
            if cmd in "Zz":
                continue
        if cmd is None or cmd in "Zz":
            sys.exit("unexpected number in path")
        if cmd in "MmLl":
            dx, dy = float(tokens[i]), float(tokens[i + 1])
            i += 2
            x, y = (x + dx, y + dy) if cmd.islower() else (dx, dy)
            cmd = {"M": "L", "m": "l"}.get(cmd, cmd)
        elif cmd in "Hh":
            v = float(tokens[i])
            i += 1
            x = x + v if cmd == "h" else v
        elif cmd in "Vv":
            v = float(tokens[i])
            i += 1
            y = y + v if cmd == "v" else v
        else:
            sys.exit(f"path command {cmd!r} is not supported (straight lines only)")
        points.append((x, y))
    if len(points) > 1 and math.dist(points[0], points[-1]) < 1e-6:
        points.pop()
    return points


def split_shards(points):
    """Split a self-touching outline into separate closed shapes."""
    shards, chain = [], []
    for p in points + [points[0]]:
        hit = next((k for k, q in enumerate(chain) if math.dist(p, q) < 1e-3), None)
        if hit is None:
            chain.append(p)
        else:
            loop = chain[hit:]
            if len(loop) >= 3:
                shards.append(loop)
            chain = chain[: hit + 1]
    return shards


def inside(px, py, poly):
    result = False
    for (x1, y1), (x2, y2) in zip(poly, poly[1:] + poly[:1]):
        if (y1 > py) != (y2 > py) and px < (x2 - x1) * (py - y1) / (y2 - y1) + x1:
            result = not result
    return result


def hex_rgb(h):
    return tuple(int(h[i : i + 2], 16) for i in (1, 3, 5))


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    svg, out = Path(sys.argv[1]), Path(sys.argv[2])
    shards = split_shards(parse_path(svg.read_text()))

    xs = [p[0] for s in shards for p in s]
    ys = [p[1] for s in shards for p in s]
    x0, y0 = min(xs), min(ys)
    sy = (ROWS * 2 - 2) / (max(ys) - y0)  # 1 pixel margin top and bottom
    sx = sy * CELL_ASPECT
    cols = (math.ceil((max(xs) - x0) * sx) + 3) // 2 + 1
    width_px, height_px = cols * 2, ROWS * 2
    px_shards = [[((x - x0) * sx + 1, (y - y0) * sy + 1) for x, y in s] for s in shards]

    # Which pixels the logo covers.
    pixels = [[False] * width_px for _ in range(height_px)]
    for j in range(height_px):
        for i in range(width_px):
            for shard in px_shards:
                hits = sum(
                    inside(i + (a + 0.5) / SAMPLES, j + (b + 0.5) / SAMPLES, shard)
                    for a in range(SAMPLES)
                    for b in range(SAMPLES)
                )
                if hits * 2 >= SAMPLES * SAMPLES:
                    pixels[j][i] = True
                    break

    # Cells: (character, base colour) or None where the logo is empty.
    base = []
    for r in range(ROWS):
        row = []
        for c in range(cols):
            bits = sum(
                1 << bit
                for bit, (j, i) in enumerate(((0, 0), (0, 1), (1, 0), (1, 1)))
                if pixels[r * 2 + j][c * 2 + i]
            )
            colour = GRADIENT[min(len(GRADIENT) - 1, int(c / cols * len(GRADIENT)))]
            row.append((QUADRANTS[bits], colour) if bits else None)
        base.append(row)

    # The pulse travels from the tail (lowest-left point) to the tip (the
    # right-most point); each cell's place along that line decides when it
    # lights up.
    pts = [p for s in px_shards for p in s]
    tail = max(pts, key=lambda p: p[1] - p[0] * 0.01)
    tip = max(pts, key=lambda p: p[0])
    ax, ay = tip[0] - tail[0], (tip[1] - tail[1]) * CELL_ASPECT / 2
    length = math.hypot(ax, ay)

    def along(r, c):
        dx, dy = (c * 2 + 1) - tail[0], ((r * 2 + 1) - tail[1]) * CELL_ASPECT / 2
        return (dx * ax + dy * ay) / (length * length)

    tip_r, tip_c = tip[1] / 2, tip[0] / 2

    def frame(recolour=None, sparks=()):
        cells = [list(row) for row in base]
        if recolour:
            for r in range(ROWS):
                for c in range(cols):
                    if cells[r][c]:
                        colour = recolour(r, c)
                        if colour:
                            cells[r][c] = (cells[r][c][0], colour)
        for r, c, ch, colour in sparks:
            if 0 <= r < ROWS and 0 <= c < cols and cells[r][c] is None:
                cells[r][c] = (ch, colour)
        return cells

    frames = []
    for f in range(PULSE_FRAMES):
        centre = -0.15 + 1.3 * f / (PULSE_FRAMES - 1)

        def pulse(r, c, centre=centre):
            d = abs(along(r, c) - centre)
            for k, limit in enumerate((0.035, 0.07, 0.11)):
                if d < limit:
                    return PULSE[k]
            return None

        frames.append(frame(pulse))

    # The flare: the tip glows and a few sparks drift out from it, fading.
    spark_dirs = [(-1.0, 1.2), (0.0, 1.6), (1.0, 1.1), (-1.6, 0.4), (1.5, 0.3)]
    for f in range(FLARE_FRAMES):
        glow = f < FLARE_FRAMES // 2

        def flare(r, c, glow=glow):
            d = math.hypot(c + 0.5 - tip_c, (r + 0.5 - tip_r) * CELL_ASPECT / 2)
            return PULSE[0] if glow and d < 3.5 else None

        dist = 1 + f
        fade = SPARK[min(len(SPARK) - 1, f * len(SPARK) // FLARE_FRAMES)]
        ch = "•" if f < 2 else "·"
        sparks = [
            (round(tip_r + dr * dist / 2), round(tip_c + dc * dist), ch, fade)
            for dr, dc in spark_dirs
        ]
        frames.append(frame(flare, sparks))

    still = frame()
    frames.extend([still] * REST_FRAMES)
    frames.insert(0, still)  # the loop starts and ends on the still logo

    def to_ansi(cells):
        lines = []
        for row in cells:
            line, current = "", None
            for cell in row:
                if cell is None:
                    line += " "
                    continue
                ch, colour = cell
                if colour != current:
                    line += "\x1b[38;2;%d;%d;%dm" % hex_rgb(colour)
                    current = colour
                line += ch
            lines.append(line + "\x1b[0m")
        return "\n".join(lines)

    out.mkdir(parents=True, exist_ok=True)
    (out / "logo.loop").write_text("\0".join(to_ansi(f) for f in frames))

    # Still logo for fastfetch: $N switches to colour N of the gradient.
    lines = []
    for row in still:
        line, current = "", None
        for cell in row:
            if cell is None:
                line += " "
                continue
            ch, colour = cell
            if colour != current:
                line += "$%d" % (GRADIENT.index(colour) + 1)
                current = colour
            line += ch
        lines.append(line.rstrip())
    (out / "logo.txt").write_text("\n".join(lines) + "\n")

    seconds = len(frames) / FPS
    print(f"logo: {cols} x {ROWS} cells, {len(shards)} shards; loop: {len(frames)} frames, {seconds:.1f} s at {FPS} fps")


if __name__ == "__main__":
    main()
