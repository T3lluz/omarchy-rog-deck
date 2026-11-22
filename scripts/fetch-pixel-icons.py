#!/usr/bin/env python3
"""
Build components/Pixels.js, ROG Deck's pixel icons, from Pixelarticons (MIT,
https://pixelarticons.com), plus the few it lacks, drawn here on the same
grid in the same weight: a CPU that reads at twelve pixels, the dials for
Balanced and Turbo, the fan (two frames, so it can spin) and the AniMe
Matrix's dots. The same pipeline as Batteries and Sonus.

Pixelarticons are drawn on a 24-unit grid with two-unit strokes. Their SVGs
are outlines of rectangles, so each icon turns into an exact grid of pixels:
a cell is on when its centre is inside the shape. PixelIcon.qml draws the
grid as rectangles on whole device pixels, so the icons stay sharp at any
scale. Small sizes use the same grid halved (see `halve`). Run from the repo
root:

    python3 scripts/fetch-pixel-icons.py          # writes components/Pixels.js
    python3 scripts/fetch-pixel-icons.py --show   # prints every grid
"""

import io
import json
import os
import re
import sys
import tarfile
import urllib.request

sys.dont_write_bytecode = True

VERSION = "2.4.2"
TARBALL = "https://registry.npmjs.org/pixelarticons/-/pixelarticons-%s.tgz" % VERSION
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

# The icons the panel, the bar and the hover card draw, by the name
# Pixelarticons gives them.
ICONS = [
    # The mark: the app icon's flame.
    "fire",
    # The rooms.
    "gpu", "thermometer", "monitor", "keyboard", "leaf",
    "battery", "battery-low", "battery-medium", "battery-full",
    # Marks beside a figure.
    "zap", "plug", "lock",
    # Inside the rooms and on the settings page.
    "sun", "moon", "power", "power-off", "bed", "clock", "eye", "binary",
    "wifi", "volume-2", "snowflake", "wind", "undo", "layout", "sparkles",
    "colors-swatch", "sliders-horizontal",
    # The panel's buttons and the kit's glyphs.
    "chevron-down", "chevron-left", "chevron-right", "settings-cog",
    "arrow-left", "check", "close", "reload", "download", "warning-diamond",
    "circle-info",
]

# Drawn here on a 12-cell grid (each cell two units), in Pixelarticons'
# weight: one-cell lines, corners cut square.
CUSTOM = {
    # A CPU that reads at the bar's twelve pixels: a square body, two long
    # pins a side and a small die, with room between them. Pixelarticons'
    # own, and a first try with three pins a side and cut corners, packed so
    # much into twelve pixels that they read as a sun.
    "cpu": [
        "....#..#....",
        "....#..#....",
        "..########..",
        "..#......#..",
        "###......###",
        "..#..##..#..",
        "..#..##..#..",
        "###......###",
        "..#......#..",
        "..########..",
        "....#..#....",
        "....#..#....",
    ],
    # Balanced and Turbo (Silent is the leaf, as in Omarchy's power menu): a
    # dial, its needle upright, then swung to fast. Pixelarticons' speed
    # icons are half circles, half as tall as the bar's other icons, which
    # read small and faint beside them; a three-quarter dial fills the square.
    "speed-medium": [
        "............",
        "....###.....",
        "..##...##...",
        ".#...#...#..",
        "#....#....#.",
        "#....#....#.",
        "#....#....#.",
        "#...###...#.",
        "#.........#.",
        ".#.......#..",
        "..#.....#...",
        "............",
    ],
    "speed-fast": [
        "............",
        "....###.....",
        "..##...##...",
        ".#.......#..",
        "#......#..#.",
        "#.....#...#.",
        "#....#....#.",
        "#...###...#.",
        "#.........#.",
        ".#.......#..",
        "..#.....#...",
        "............",
    ],
    # A pinwheel of four teardrop blades round a hub. "fan-2" is the same
    # fan an eighth of a turn on, so flipping between the two spins it
    # without turning pixel art off the quarter turns.
    "fan": [
        "....###.....",
        "...#...#....",
        "...#...#....",
        "....#..#.##.",
        ".#####.##..#",
        "#....###...#",
        "#...###....#",
        "#..##.#####.",
        ".##.#..#....",
        "....#...#...",
        "....#...#...",
        ".....###....",
    ],
    "fan-2": [
        "........##..",
        ".##....#..#.",
        "#..#...#..#.",
        "#...#..#.#..",
        ".####..##...",
        ".....##.....",
        ".....##.....",
        "...##..####.",
        "..#.#..#...#",
        ".#..#...#..#",
        ".#..#....##.",
        "..##........",
    ],
    # The AniMe Matrix: the lid's grid of LEDs.
    "matrix": [
        "............",
        ".#.#.#.#.#..",
        "............",
        ".#.#.#.#.#..",
        "............",
        ".#.#.#.#.#..",
        "............",
        ".#.#.#.#.#..",
        "............",
        ".#.#.#.#.#..",
        "............",
        "............",
    ],
}

# The 12-cell grid of an icon drawn here instead of halving the 24, for an
# icon whose strokes sit off the odd units. None at the moment.
SMALL = {}


def polygons(d):
    """Rectilinear subpaths of an SVG path (M, H, V, L, h, v, l, m, Z)."""
    tokens = re.findall(r"[MmHhVvLlZz]|-?\d*\.?\d+", d)
    polys, cur, x, y, cmd, i = [], [], 0.0, 0.0, None, 0
    while i < len(tokens):
        t = tokens[i]
        if re.match(r"[A-Za-z]", t):
            cmd = t
            i += 1
            if cmd in "Zz":
                if cur:
                    polys.append(cur)
                    x, y = cur[0]
                cur = []
            continue
        if cmd in "Mm":
            nx, ny = float(tokens[i]), float(tokens[i + 1])
            i += 2
            if cmd == "m":
                nx, ny = x + nx, y + ny
            if cur:
                polys.append(cur)
            cur = [(nx, ny)]
            x, y = nx, ny
            cmd = "l" if cmd == "m" else "L"
        elif cmd in "Ll":
            nx, ny = float(tokens[i]), float(tokens[i + 1])
            i += 2
            if cmd == "l":
                nx, ny = x + nx, y + ny
            x, y = nx, ny
            cur.append((x, y))
        elif cmd in "Hh":
            v = float(tokens[i]); i += 1
            x = x + v if cmd == "h" else v
            cur.append((x, y))
        elif cmd in "Vv":
            v = float(tokens[i]); i += 1
            y = y + v if cmd == "v" else v
            cur.append((x, y))
        else:
            raise SystemExit("unsupported path command %r" % cmd)
    if cur:
        polys.append(cur)
    return polys


def raster(svg):
    """The 24x24 grid of an icon: rows of booleans, nonzero winding."""
    edges = []
    for d in re.findall(r'<path[^>]*\sd="([^"]+)"', svg):
        for poly in polygons(d):
            for (x0, y0), (x1, y1) in zip(poly, poly[1:] + poly[:1]):
                if x0 == x1 and y0 != y1:
                    edges.append((x0, y0, y1))
    for m in re.finditer(r'<rect[^>]*>', svg):
        a = dict(re.findall(r'(\w+)="([^"]+)"', m.group(0)))
        x, y, w, h = (float(a.get(k, 0)) for k in ("x", "y", "width", "height"))
        edges += [(x, y + h, y), (x + w, y, y + h)]
    if re.search(r"<(circle|ellipse|polygon|polyline|line)\b", svg):
        raise SystemExit("expected only paths and rects")
    grid = []
    for row in range(24):
        cy = row + 0.5
        line = []
        for col in range(24):
            cx = col + 0.5
            wind = 0
            for x, y0, y1 in edges:
                if x > cx and min(y0, y1) < cy < max(y0, y1):
                    wind += 1 if y1 > y0 else -1
            line.append(wind != 0)
        grid.append(line)
    return grid


def from_art(art):
    """A 12-cell drawing at 24 units: each cell two by two."""
    return [[art[r // 2][c // 2] == "#" for c in range(24)] for r in range(24)]


def halve(grid):
    # Every stroke is two units wide, so it covers exactly one odd unit:
    # sampling those keeps each stroke one cell wide, wherever it starts.
    return [[grid[r * 2 + 1][c * 2 + 1] for c in range(12)] for r in range(12)]


def rects(grid):
    """Runs along each row, merged down where the next rows repeat them."""
    n = len(grid)
    runs = []
    for r, line in enumerate(grid):
        c = 0
        while c < n:
            if line[c]:
                s = c
                while c < n and line[c]:
                    c += 1
                runs.append([s, r, c - s, 1])
            else:
                c += 1
    merged = []
    for run in runs:
        for m in merged:
            if m[0] == run[0] and m[2] == run[2] and m[1] + m[3] == run[1]:
                m[3] += 1
                break
        else:
            merged.append(list(run))
    return merged


def show(grid):
    return "\n".join("".join("#" if v else "." for v in line) for line in grid)


def small(name, grid):
    if name in SMALL:
        return [[ch == "#" for ch in row] for row in SMALL[name]]
    return halve(grid)


def main():
    with urllib.request.urlopen(TARBALL, timeout=30) as r:
        pack = tarfile.open(fileobj=io.BytesIO(r.read()))
    out = {}
    for name in ICONS:
        svg = pack.extractfile("package/svg/%s.svg" % name).read().decode()
        with open(os.path.join(ROOT, "pixels", name + ".svg"), "w") as f:
            f.write(svg)
        out[name] = raster(svg)
    for name, art in CUSTOM.items():
        out[name] = from_art(art)
    if "--show" in sys.argv:
        for name, grid in out.items():
            print(name)
            print(show(grid))
            print(show(small(name, grid)))
            print()
        return
    lines = [
        ".pragma library",
        "",
        "// Generated by scripts/fetch-pixel-icons.py from Pixelarticons %s (MIT," % VERSION,
        "// https://pixelarticons.com), plus the fan and the AniMe Matrix drawn there on the",
        "// same grid. Each icon is [x, y, width, height] rectangles: `g24` on the 24-unit grid,",
        "// `g12` on the same grid halved for small sizes.",
        "",
        "var icons = {",
    ]
    for name, grid in out.items():
        lines.append("  %s: { g24: %s, g12: %s }," % (json.dumps(name), json.dumps(rects(grid)), json.dumps(rects(small(name, grid)))))
    lines[-1] = lines[-1].rstrip(",")
    lines += ["}", ""]
    with open(os.path.join(ROOT, "components", "Pixels.js"), "w") as f:
        f.write("\n".join(lines))
    print("wrote components/Pixels.js with %d icons" % len(out))


if __name__ == "__main__":
    main()
