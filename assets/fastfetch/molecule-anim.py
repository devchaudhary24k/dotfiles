#!/usr/bin/env python3
"""Draw carbon's fastfetch logo: a benzene ring, with electrons that orbit it.

    python3 assets/fastfetch/molecule-anim.py hosts/carbon/home/.config/fastfetch

Writes the same two files as logo-anim.py does for nukebyte:

  logo.txt   the still molecule, in fastfetch's file-logo format ($1..$6 pick
             the colours set in the shared config.jsonc)
  logo.loop  the idle animation `ff-logo` plays over it: frames of 24-bit
             colour text separated by NUL bytes, frame 0 being the still logo

Six carbon atoms sit on a hexagon with a hydrogen outside each one, and the
aromatic ring is drawn inside. In the animation three electrons fade in, run
once around that ring while each carbon lights up as one passes, fade out,
and the molecule rests. It is drawn with quadrant block characters (2 x 2
"pixels" per cell), like the nukebyte logo, and is the same height.
"""

import math
import sys
from pathlib import Path

# Layout, matching logo-anim.py: 12 rows, cells 2.15 times taller than wide.
ROWS = 12
COLS = 28
CELL_ASPECT = 2.15
SAMPLES = 4  # per pixel side, for anti-aliased coverage
COVERAGE = 0.4  # share of a pixel a shape must cover to light it

# The shared fastfetch palette ($1..$6 in config.jsonc), dark to light.
GRADIENT = ["#6c7086", "#7f849c", "#9399b2", "#bac2de", "#dfe3f2", "#f2f2f2"]
# Carbon's own accent for the electrons (Catppuccin Mocha teal and sky).
ELECTRON = "#ffffff"
TRAIL = "#94e2d5"
GLOW = "#89dceb"

FPS = 12
ORBIT_FRAMES = 48  # one lap of the ring: 4 s
FADE_FRAMES = 8  # electrons fade in and out at the ends of the lap
REST_FRAMES = 30

QUADRANTS = " ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█"  # index = TL | TR<<1 | BL<<2 | BR<<3

# Geometry in "cell widths": x to the right, y down; one row is CELL_ASPECT tall.
# Half a pixel up, so the horizontal bonds through the centre sit inside one
# pixel row instead of straddling two (and vanishing).
CX, CY = COLS / 2, ROWS * CELL_ASPECT / 2 - CELL_ASPECT / 4
RING = 7.0  # carbon atoms from the centre
HYDROGEN = 11.2  # hydrogen atoms from the centre
INNER = 4.1  # the aromatic ring inside
ANGLES = [math.radians(60 * k) for k in range(6)]  # flat top and bottom


def polar(radius, angle):
    return CX + radius * math.cos(angle), CY + radius * math.sin(angle)


CARBONS = [polar(RING, a) for a in ANGLES]
HYDROGENS = [polar(HYDROGEN, a) for a in ANGLES]


def segment_distance(px, py, a, b):
    (ax, ay), (bx, by) = a, b
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


# Shapes, highest priority first: (name, colour index, test(x, y) -> inside).
SHAPES = [
    ("carbon", 5, lambda x, y: any(math.hypot(x - cx, y - cy) < 1.6 for cx, cy in CARBONS)),
    ("hydrogen", 2, lambda x, y: any(math.hypot(x - hx, y - hy) < 1.05 for hx, hy in HYDROGENS)),
    (
        "ring bond",
        3,
        lambda x, y: any(
            segment_distance(x, y, CARBONS[k], CARBONS[(k + 1) % 6]) < 0.42 for k in range(6)
        ),
    ),
    (
        "hydrogen bond",
        1,
        lambda x, y: any(segment_distance(x, y, CARBONS[k], HYDROGENS[k]) < 0.32 for k in range(6)),
    ),
    ("aromatic ring", 4, lambda x, y: abs(math.hypot(x - CX, y - CY) - INNER) < 0.36),
]


def hex_rgb(h):
    return tuple(int(h[i : i + 2], 16) for i in (1, 3, 5))


def mix(a, b, t):
    ra, rb = hex_rgb(a), hex_rgb(b)
    return "#%02x%02x%02x" % tuple(round(x + (y - x) * t) for x, y in zip(ra, rb))


def build_cells():
    """Each cell: (character, shape name, base colour), or None when empty."""
    px_w, px_h = 0.5, CELL_ASPECT / 2
    pixel_shape = {}
    for j in range(ROWS * 2):
        for i in range(COLS * 2):
            counts = {}
            for a in range(SAMPLES):
                for b in range(SAMPLES):
                    x = (i + (a + 0.5) / SAMPLES) * px_w
                    y = (j + (b + 0.5) / SAMPLES) * px_h
                    for name, _, test in SHAPES:
                        if test(x, y):
                            counts[name] = counts.get(name, 0) + 1
                            break
            total = sum(counts.values())
            if total >= COVERAGE * SAMPLES * SAMPLES:
                pixel_shape[(j, i)] = max(counts, key=lambda n: (counts[n], -order(n)))

    cells = []
    for r in range(ROWS):
        row = []
        for c in range(COLS):
            quads = [(r * 2 + j, c * 2 + i) for j, i in ((0, 0), (0, 1), (1, 0), (1, 1))]
            bits = sum(1 << k for k, q in enumerate(quads) if q in pixel_shape)
            if not bits:
                row.append(None)
                continue
            names = [pixel_shape[q] for q in quads if q in pixel_shape]
            name = min(names, key=order)  # the highest-priority shape in the cell
            colour = GRADIENT[next(ci for n, ci, _ in SHAPES if n == name)]
            row.append((QUADRANTS[bits], name, colour))
        cells.append(row)
    return cells


def order(name):
    return [n for n, _, _ in SHAPES].index(name)


def cell_centre(r, c):
    return c + 0.5, (r + 0.5) * CELL_ASPECT


def angle_gap(a, b):
    return abs((a - b + math.pi) % (2 * math.pi) - math.pi)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out = Path(sys.argv[1])
    base = build_cells()

    def frame(f):
        """Frame f of the lap; None draws the still molecule."""
        cells = [[(cell[0], cell[2]) if cell else None for cell in row] for row in base]
        if f is None:
            return cells
        envelope = min(1.0, f / FADE_FRAMES, (ORBIT_FRAMES - 1 - f) / FADE_FRAMES)
        envelope = max(0.0, envelope)
        heads = [-math.pi / 2 + 2 * math.pi * (f / ORBIT_FRAMES + k / 3) for k in range(3)]
        for r, row in enumerate(base):
            for c, cell in enumerate(row):
                if not cell:
                    continue
                x, y = cell_centre(r, c)
                angle = math.atan2(y - CY, x - CX)
                gap = min(angle_gap(angle, h) for h in heads)
                ch, name, colour = cell
                if name == "aromatic ring":
                    # The electron, with a short teal trail behind it.
                    behind = min(((h - angle) % (2 * math.pi)) for h in heads)
                    if gap < 0.22:
                        colour = mix(colour, ELECTRON, envelope)
                    elif behind < 0.9:
                        colour = mix(colour, TRAIL, envelope * (1 - behind / 0.9))
                elif name == "carbon" and gap < 0.45:
                    colour = mix(colour, GLOW, envelope * (1 - gap / 0.45))
                cells[r][c] = (ch, colour)
        return cells

    still = frame(None)
    frames = [still] + [frame(f) for f in range(ORBIT_FRAMES)] + [still] * REST_FRAMES

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
    print(f"molecule: {COLS} x {ROWS} cells; loop: {len(frames)} frames, {len(frames) / FPS:.1f} s at {FPS} fps")


if __name__ == "__main__":
    main()
