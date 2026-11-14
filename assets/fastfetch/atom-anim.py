#!/usr/bin/env python3
"""Draw carbon's fastfetch logo: a carbon atom with its electrons in motion.

    python3 assets/fastfetch/atom-anim.py hosts/carbon/fastfetch/.config/fastfetch

Writes the same two files as logo-anim.py does for nukebyte:

  logo.txt   the still atom, in fastfetch's file-logo format ($1..$7 pick
             the colours set in the shared config.jsonc)
  logo.loop  the idle animation `ff-logo` plays over it: frames of 24-bit
             colour text separated by NUL bytes, frame 0 being the still logo

A nucleus sits where three tilted orbits cross, the familiar atom symbol.
Each orbit carries two electrons, six in all: carbon's number. The electrons
circle without stopping. Two electrons on an orbit are half a turn apart, so
half a turn brings the picture back to where it started and the loop has no
seam; the still logo is simply the first frame of it. It is drawn with
quadrant block characters (2 x 2 "pixels" per cell) and is as tall as the
nukebyte logo.
"""

import math
import sys
from pathlib import Path

# Layout, matching logo-anim.py: 12 rows, cells 2.15 times taller than wide.
ROWS = 12
COLS = 30
CELL_ASPECT = 2.15
SAMPLES = 4  # per pixel side, for anti-aliased coverage
COVERAGE = 0.38  # share of a pixel a shape must cover to light it

# The shared fastfetch palette: $1..$6 greys to white, $7 carbon's teal.
PALETTE = ["#6c7086", "#7f849c", "#9399b2", "#bac2de", "#dfe3f2", "#f2f2f2", "#94e2d5"]
ORBIT, NUCLEUS, ELECTRON = PALETTE[2], PALETTE[5], PALETTE[6]

FPS = 12
HALF_TURN_FRAMES = 36  # electrons move half a turn per loop: 3 s, 6 s a lap

QUADRANTS = " ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█"  # index = TL | TR<<1 | BL<<2 | BR<<3

# Geometry in "cell widths": x to the right, y down; one row is CELL_ASPECT tall.
CX, CY = COLS / 2, ROWS * CELL_ASPECT / 2
SEMI_MAJOR, SEMI_MINOR = 12.6, 5.2
TILTS = [math.radians(t) for t in (0, 60, -60)]
STROKE = 0.42  # half the width of an orbit line
NUCLEUS_RADIUS = 2.0
ELECTRON_RADIUS = 1.15


def to_orbit(x, y, tilt):
    """A point in the frame of an orbit: centred, turned so the orbit is level."""
    dx, dy = x - CX, y - CY
    c, s = math.cos(tilt), math.sin(tilt)
    return dx * c + dy * s, -dx * s + dy * c


def on_orbit(x, y, tilt):
    u, v = to_orbit(x, y, tilt)
    f = (u / SEMI_MAJOR) ** 2 + (v / SEMI_MINOR) ** 2 - 1
    gradient = math.hypot(2 * u / SEMI_MAJOR**2, 2 * v / SEMI_MINOR**2) or 1e-9
    return abs(f) / gradient < STROKE  # distance to the ellipse, near enough


def electron_positions(frame):
    """Where the six electrons are in this frame."""
    turned = math.pi * frame / HALF_TURN_FRAMES
    positions = []
    for k, tilt in enumerate(TILTS):
        for half in (0, math.pi):
            phase = turned + half + k * math.pi / 3  # orbits start out of step
            u, v = SEMI_MAJOR * math.cos(phase), SEMI_MINOR * math.sin(phase)
            c, s = math.cos(tilt), math.sin(tilt)
            positions.append((CX + u * c - v * s, CY + u * s + v * c))
    return positions


def hex_rgb(h):
    return tuple(int(h[i : i + 2], 16) for i in (1, 3, 5))


def sample_points():
    px_w, px_h = 0.5, CELL_ASPECT / 2
    for j in range(ROWS * 2):
        for i in range(COLS * 2):
            yield j, i, [
                ((i + (a + 0.5) / SAMPLES) * px_w, (j + (b + 0.5) / SAMPLES) * px_h)
                for a in range(SAMPLES)
                for b in range(SAMPLES)
            ]


PIXELS = list(sample_points())
# What lies under each pixel that never moves: the nucleus, or an orbit.
STATIC = {}
for j, i, points in PIXELS:
    nucleus = sum(math.hypot(x - CX, y - CY) < NUCLEUS_RADIUS for x, y in points)
    orbit = sum(any(on_orbit(x, y, t) for t in TILTS) for x, y in points)
    limit = COVERAGE * len(points)
    if nucleus >= limit:
        STATIC[(j, i)] = NUCLEUS
    elif orbit >= limit:
        STATIC[(j, i)] = ORBIT


def frame_cells(frame):
    """Cells of one frame: (character, colour) or None. Electrons go on top."""
    electrons = electron_positions(frame)
    lit = dict(STATIC)
    for j, i, points in PIXELS:
        hits = sum(
            any(math.hypot(x - ex, y - ey) < ELECTRON_RADIUS for ex, ey in electrons)
            for x, y in points
        )
        if hits >= COVERAGE * len(points):
            lit[(j, i)] = ELECTRON
    rank = {ELECTRON: 0, NUCLEUS: 1, ORBIT: 2}
    cells = []
    for r in range(ROWS):
        row = []
        for c in range(COLS):
            quads = [(r * 2 + j, c * 2 + i) for j, i in ((0, 0), (0, 1), (1, 0), (1, 1))]
            colours = [lit[q] for q in quads if q in lit]
            if not colours:
                row.append(None)
                continue
            colour = min(colours, key=rank.get)  # the cell takes its brightest part
            # Draw only the pixels of that part, so an electron passing over an
            # orbit is a clean dot rather than a smear.
            bits = sum(1 << k for k, q in enumerate(quads) if lit.get(q) == colour)
            row.append((QUADRANTS[bits], colour))
        cells.append(row)
    return cells


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


def to_logo(cells):
    lines = []
    for row in cells:
        line, current = "", None
        for cell in row:
            if cell is None:
                line += " "
                continue
            ch, colour = cell
            if colour != current:
                line += "$%d" % (PALETTE.index(colour) + 1)
                current = colour
            line += ch
        lines.append(line.rstrip())
    return "\n".join(lines) + "\n"


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out = Path(sys.argv[1])
    frames = [frame_cells(f) for f in range(HALF_TURN_FRAMES)]
    out.mkdir(parents=True, exist_ok=True)
    (out / "logo.loop").write_text("\0".join(to_ansi(f) for f in frames))
    (out / "logo.txt").write_text(to_logo(frames[0]))
    print(f"atom: {COLS} x {ROWS} cells; loop: {len(frames)} frames, {len(frames) / FPS:.1f} s at {FPS} fps")


if __name__ == "__main__":
    main()
