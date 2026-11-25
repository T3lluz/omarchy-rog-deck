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
    python3 scripts/fetch-pixel-icons.py --parts  # each icon's moving parts, lettered
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
    # Four solid blades round a hub of their own, each blade clear of the hub
    # and of its neighbours and leaning a little the way the fan turns. The
    # pinwheel of outlined teardrops before it read as a knot at 2x and a
    # blob at 1.25. Its blades have a second frame (FAN_TURNED, an eighth of
    # a turn on), so flipping between the two spins it without turning pixel
    # art off the quarter turns. No blade bends at a right angle: four
    # hooked arms make a shape no one wants in their bar.
    "fan": [
        "....###.....",
        "....####....",
        ".....###....",
        ".....##.....",
        ".##.......##",
        "####.##.####",
        "####.##.####",
        "##.......##.",
        ".....##.....",
        "....###.....",
        "....####....",
        ".....###....",
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

# The fan an eighth of a turn on, its blades on the diagonals: their
# second frame.
FAN_TURNED = [
    "............",
    "..##....##..",
    ".####..####.",
    ".####..####.",
    "..##....##..",
    ".....##.....",
    ".....##.....",
    "..##....##..",
    ".####..####.",
    ".####..####.",
    "..##....##..",
    "............",
]


# ---------------------------------------------------------------- moving parts
#
# What moves in each icon when it plays (components/Motion.js says how). A
# part is some of the icon's own cells, picked on the 12-cell grid, and may
# have other frames drawn here as cells: the needle's positions, the fan's
# turned blades, the mercury's levels. The rest of the icon is its base and
# never moves. `steps` splits a part into that many groups, numbered from 0
# in the order `by` sorts its cells, for the parts that draw themselves in.
# Extra frames sit on the 12-cell grid; on the 24 they are two units a cell,
# placed the way the icon's own strokes are.


def R(x, y, w=1, h=1):
    return lambda c, r: x <= c < x + w and y <= r < y + h


def at(*cells):
    cells = set(cells)
    return lambda c, r: (c, r) in cells


def anyof(*picks):
    return lambda c, r: any(p(c, r) for p in picks)


def every(c, r):
    return True


def column(x, top, bottom):
    return [(x, y) for y in range(top, bottom + 1)]


def row(y, left, right):
    return [(x, y) for x in range(left, right + 1)]


def Part(name, pick=None, frames=None, rest=0, steps=0, by=None):
    return {"name": name, "pick": pick, "frames": frames, "rest": rest, "steps": steps, "by": by}


def from_centre(cx, cy):
    return lambda c, r: (c - cx) ** 2 + (r - cy) ** 2


def clockwise(cx, cy):
    import math
    return lambda c, r: (math.atan2(c - cx, cy - r) + 2 * math.pi) % (2 * math.pi)


# The dial's needle: swung back to slow, upright for Balanced, over to fast.
NEEDLE = [[(3, 4), (4, 5), (5, 6)], column(5, 3, 6), [(7, 4), (6, 5), (5, 6)]]
# A battery's bars, none to three.
BARS = [[], column(3, 4, 6), column(3, 4, 6) + column(5, 4, 6), column(3, 4, 6) + column(5, 4, 6) + column(7, 4, 6)]
FAN_HUB = R(5, 5, 2, 2)


def slider(top, knobs, gap):
    """A slider's frames: its track across the row under `top`, the knob
    standing through it at each of `knobs`, with the track's gap on the
    knob's `gap` side (-1 left, 1 right)."""
    frames = []
    for k in knobs:
        frames.append([(k, top), (k, top + 2)] + [(x, top + 1) for x in range(1, 11) if x != k + gap])
    return frames

PARTS = {
    # The flame's tip flickers while its heart leaps.
    "fire": [Part("tip", R(4, 1, 1, 2)), Part("core", R(4, 7, 3, 3))],
    # The chip's pins pulse outward, a side at a time, while the die blinks.
    "cpu": [Part("pinsN", R(0, 0, 12, 2)), Part("pinsS", R(0, 10, 12, 2)),
            Part("pinsW", R(0, 2, 2, 8)), Part("pinsE", R(10, 2, 2, 8)), Part("die", R(5, 5, 2, 2))],
    # The card's two fans turn: a plus, then the same fan an eighth on.
    "gpu": [Part("fans", anyof(R(2, 4, 3, 3), R(6, 4, 3, 3)),
                 frames=[None, [(2, 4), (4, 4), (2, 6), (4, 6), (6, 4), (8, 4), (6, 6), (8, 6)]])],
    # The mercury climbs the tube and sinks back to where it was.
    "thermometer": [Part("mercury", at((5, 8)), frames=[None] + [column(5, 8 - n, 8) for n in range(1, 6)])],
    # A line sweeps down the screen; the stand stays.
    "monitor": [Part("scan", frames=[[]] + [row(y, 2, 9) for y in range(2, 8)])],
    # The keys light up in a sweep from the left.
    "keyboard": [Part("keys", R(1, 3, 9, 5), steps=5, by=lambda c, r: c)],
    # The lid's LEDs come on corner to corner.
    "matrix": [Part("dots", every, steps=5, by=lambda c, r: c + r)],
    # The needle swings through its range and settles on the mode.
    "speed-medium": [Part("needle", R(5, 3, 1, 4), frames=[NEEDLE[0], None, NEEDLE[2]], rest=1)],
    "speed-fast": [Part("needle", at(*NEEDLE[2]), frames=[NEEDLE[0], NEEDLE[1], None], rest=2)],
    # The blades turn round the hub, which stays put.
    "fan": [Part("blades", lambda c, r: not FAN_HUB(c, r), frames=[None, [
        (c, r) for r, line in enumerate(FAN_TURNED) for c, ch in enumerate(line) if ch == "#" and not FAN_HUB(c, r)]])],
    # The bars fill one by one, then fall back to the level.
    "battery": [Part("bars", frames=[BARS[0], BARS[1], BARS[2], BARS[3]], rest=0)],
    "battery-low": [Part("bars", R(3, 4, 1, 3), frames=[BARS[0], None, BARS[2], BARS[3]], rest=1)],
    "battery-medium": [Part("bars", anyof(R(3, 4, 1, 3), R(5, 4, 1, 3)), frames=[BARS[0], BARS[1], None, BARS[3]], rest=2)],
    "battery-full": [Part("bars", anyof(R(3, 4, 1, 3), R(5, 4, 1, 3), R(7, 4, 1, 3)), frames=[BARS[0], BARS[1], BARS[2], None], rest=3)],
    # The plug lifts and seats itself; the cord stays.
    "plug": [Part("body", R(0, 0, 12, 9))],
    # The shackle lifts and snaps shut.
    "lock": [Part("shackle", R(0, 0, 12, 4))],
    # The rays flash in turn: the straight ones, then the slanted.
    "sun": [Part("straight", at((5, 1), (5, 9), (5, 10), (1, 5), (9, 5), (10, 5))),
            Part("slanted", at((2, 2), (8, 2), (2, 8), (8, 8)))],
    # A star twinkles beside the moon.
    "moon": [Part("star", frames=[[], [(9, 2)], [(9, 1), (8, 2), (9, 2), (10, 2), (9, 3)]])],
    # The button is pressed in.
    "power": [Part("stem", R(5, 0, 1, 5))],
    # The slash draws across, top left to bottom right.
    "power-off": [Part("slash", lambda c, r: c == r, steps=5, by=lambda c, r: c)],
    # A Z drifts up from the pillow.
    "bed": [Part("z", frames=[[], [(8, 1), (9, 1), (10, 1), (9, 2), (8, 3), (9, 3), (10, 3)]])],
    # The minute hand goes round once; the hour hand holds.
    "clock": [Part("minute", R(5, 3, 1, 3), frames=[None, row(5, 5, 7), column(5, 5, 7), row(5, 3, 5)])],
    # The eye blinks, then glances one way and the other.
    "eye": [Part("lidTop", R(2, 2, 8, 2)), Part("lidBottom", R(2, 8, 8, 2)), Part("pupil", R(4, 4, 4, 4))],
    # The bits flip, a digit at a time.
    "binary": [Part("bit", every, steps=4, by=lambda c, r: (0 if r < 5 else 2) + (0 if c < 5 else 1))],
    # The waves go out from the dot.
    "wifi": [Part("wave", lambda c, r: r < 9, steps=3, by=from_centre(5, 9))],
    # The sound goes out from the speaker.
    "volume-2": [Part("wave", lambda c, r: c >= 6, steps=2, by=lambda c, r: c)],
    # The crystal grows from its heart.
    "snowflake": [Part("arm", lambda c, r: abs(c - 5) + abs(r - 5) > 1, steps=3, by=from_centre(5, 5))],
    # Gusts blow through, one line after another.
    "wind": [Part("gust0", R(0, 0, 12, 3)), Part("gust1", R(0, 3, 12, 3)), Part("gust2", R(0, 6, 12, 6))],
    # The arrow's head pulls back.
    "undo": [Part("head", R(0, 0, 5, 12))],
    # The arrow runs round its circle.
    "reload": [Part("arc", every, steps=6, by=clockwise(5.5, 5.5))],
    "arrow-left": [Part("head", R(0, 0, 6, 12))],
    # The tick draws itself, short stroke first.
    "check": [Part("stroke", every, steps=4, by=lambda c, r: c)],
    # One stroke, then the other.
    "close": [Part("one", lambda c, r: c == r), Part("two", lambda c, r: c != r)],
    # The arrow drops into the tray.
    "download": [Part("arrow", R(3, 0, 5, 8))],
    # The warning flashes.
    "warning-diamond": [Part("bang", R(5, 3, 1, 6))],
    # The dot over the i hops.
    "circle-info": [Part("dot", R(5, 3, 1, 1))],
    # The small sparkle twinkles.
    "sparkles": [Part("small", R(8, 0, 4, 3))],
    # The pane's divider slides over and back.
    "layout": [Part("divider", R(4, 5, 1, 4))],
    # The swatches fan out, front to back.
    "colors-swatch": [Part("card", every, steps=3, by=lambda c, r: -c)],
    # Each knob slides along its track, the gap beside it going along.
    "sliders-horizontal": [Part("knobA", R(0, 1, 12, 3), frames=slider(1, [4, 5, 6], -1), rest=2),
                           Part("knobB", R(0, 4, 12, 3), frames=slider(4, [3, 4, 5], 1), rest=0),
                           Part("knobC", R(0, 8, 12, 3), frames=slider(8, [6, 7, 8], -1), rest=1)],
    # The leaf is the whole icon; it drifts (Motion.js), as does the flame
    # mark's sway, the chevrons' nudge and the cog's notch.
}


def unit_cells(name, grid24, align):
    """The 12-cell each lit unit of the 24-unit grid belongs to. Mostly the
    cell the halving samples it into; a unit of a one-unit stroke (the
    slash's staircase) can fall in a cell the halving leaves empty, and then
    it joins the lit cell beside it, so it moves with its stroke."""
    g12 = small(name, grid24)
    lit = lambda c, r: 0 <= c < 12 and 0 <= r < 12 and g12[r][c]
    owner = {}
    for y in range(24):
        for x in range(24):
            if not grid24[y][x]:
                continue
            first = ((x - align) // 2, (y - align) // 2)
            if lit(*first):
                owner[(x, y)] = first
                continue
            for c in ((x - 1) // 2, x // 2):
                for r in ((y - 1) // 2, y // 2):
                    if (x, y) not in owner and lit(c, r):
                        owner[(x, y)] = (c, r)
    return g12, owner


def block(cells, align):
    """Extra cells on both grids."""
    cells = sorted(set(cells))
    g12 = [[False] * 12 for _ in range(12)]
    g24 = [[False] * 24 for _ in range(24)]
    for c, r in cells:
        g12[r][c] = True
        for dy in range(2):
            for dx in range(2):
                y, x = 2 * r + align + dy, 2 * c + align + dx
                if 0 <= x < 24 and 0 <= y < 24:
                    g24[y][x] = True
    return g24, g12


def split(name, grid24, align):
    """The icon's base and its parts, each frame on both grids, or None for an
    icon that moves whole."""
    if name not in PARTS:
        return None
    g12, owner = unit_cells(name, grid24, align)
    taken12 = [[False] * 12 for _ in range(12)]
    taken24 = [[False] * 24 for _ in range(24)]
    parts = []

    def own(pick):
        o12 = [[g12[r][c] and not taken12[r][c] and pick(c, r) for c in range(12)] for r in range(12)]
        o24 = [[(x, y) in owner and not taken24[y][x] and o12[owner[(x, y)][1]][owner[(x, y)][0]]
                for x in range(24)] for y in range(24)]
        return o24, o12

    def take(o24, o12):
        for r in range(12):
            for c in range(12):
                taken12[r][c] = taken12[r][c] or o12[r][c]
        for y in range(24):
            for x in range(24):
                taken24[y][x] = taken24[y][x] or o24[y][x]

    for spec in PARTS[name]:
        if spec["steps"]:
            o24, o12 = own(spec["pick"])
            take(o24, o12)
            keys = sorted({spec["by"](c, r) for r in range(12) for c in range(12) if o12[r][c]})
            n = spec["steps"]
            for i in range(n):
                group = set(keys[len(keys) * i // n: len(keys) * (i + 1) // n])
                inside = lambda c, r, group=group: spec["by"](c, r) in group
                p24 = [[o24[y][x] and inside(*owner[(x, y)]) for x in range(24)] for y in range(24)]
                p12 = [[o12[r][c] and inside(c, r) for c in range(12)] for r in range(12)]
                parts.append({"name": "%s%d" % (spec["name"], i), "rest": 0, "frames": [(p24, p12)]})
            continue
        mine = own(spec["pick"]) if spec["pick"] else None
        if mine:
            take(*mine)
        frames = []
        own12 = {(c, r) for r in range(12) for c in range(12) if mine and mine[1][r][c]}
        for i, f in enumerate(spec["frames"] or [None]):
            # A frame that is the icon's own cells keeps its own strokes on
            # the 24-unit grid, which can be finer than two units a cell.
            if f is None or (mine and set(f) == own12):
                frames.append(mine)
            else:
                frames.append(block(f, align))
        parts.append({"name": spec["name"], "rest": spec["rest"], "frames": frames})
    base24 = [[grid24[y][x] and not taken24[y][x] for x in range(24)] for y in range(24)]
    base12 = [[g12[r][c] and not taken12[r][c] for c in range(12)] for r in range(12)]
    return (base24, base12), parts


def show_parts(name, grid24, align):
    split_ = split(name, grid24, align)
    if not split_:
        return name + ": moves whole\n" + show(small(name, grid24))
    (b24, b12), parts = split_
    canvas = [["#" if b12[r][c] else "." for c in range(12)] for r in range(12)]
    legend = []
    for i, p in enumerate(parts):
        mark = "abcdefghijklmnopqrstuvwxyz"[i]
        legend.append("%s=%s(%d frames, rest %d)" % (mark, p["name"], len(p["frames"]), p["rest"]))
        g12 = p["frames"][p["rest"]][1]
        for r in range(12):
            for c in range(12):
                if g12[r][c]:
                    canvas[r][c] = mark
    text = name + ": " + " ".join(legend) + "\n" + "\n".join("".join(line) for line in canvas)
    for i, p in enumerate(parts):
        if len(p["frames"]) < 2:
            continue
        shots = []
        for f24, f12 in p["frames"]:
            shot = [["#" if b12[r][c] else "." for c in range(12)] for r in range(12)]
            for r in range(12):
                for c in range(12):
                    if f12[r][c]:
                        shot[r][c] = "o"
            shots.append(shot)
        text += "\n  %s frames:\n" % p["name"] + "\n".join("  " + "  ".join("".join(shot[r]) for shot in shots) for r in range(12))
    return text


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
    # Pixelarticons' strokes start on odd units, the ones drawn here on even.
    align = {}
    for name in ICONS:
        svg = pack.extractfile("package/svg/%s.svg" % name).read().decode()
        with open(os.path.join(ROOT, "pixels", name + ".svg"), "w") as f:
            f.write(svg)
        out[name] = raster(svg)
        align[name] = 1
    for name, art in CUSTOM.items():
        out[name] = from_art(art)
        align[name] = 0
    if "--show" in sys.argv:
        for name, grid in out.items():
            print(name)
            print(show(grid))
            print(show(small(name, grid)))
            print()
        return
    if "--parts" in sys.argv:
        for name, grid in out.items():
            print(show_parts(name, grid, align[name]))
            print()
        return
    lines = [
        ".pragma library",
        "",
        "// Generated by scripts/fetch-pixel-icons.py from Pixelarticons %s (MIT," % VERSION,
        "// https://pixelarticons.com), plus the CPU, the dials, the fan and the AniMe",
        "// Matrix drawn there on the same grid. Each icon is [x, y, width, height]",
        "// rectangles: `g24` on the 24-unit grid, `g12` on the same grid halved for",
        "// small sizes. An icon with moving parts also has `base`, what never moves,",
        "// and `parts`, each with its frames and the frame it rests on",
        "// (components/Motion.js plays them).",
        "",
        "var icons = {",
    ]
    for name, grid in out.items():
        entry = "  %s: { g24: %s, g12: %s" % (json.dumps(name), json.dumps(rects(grid)), json.dumps(rects(small(name, grid))))
        moving = split(name, grid, align[name])
        if moving:
            (b24, b12), parts = moving
            entry += ",\n    base: { g24: %s, g12: %s },\n    parts: [" % (json.dumps(rects(b24)), json.dumps(rects(b12)))
            entry += ",".join("\n      { name: %s, rest: %d, frames: [%s] }" % (
                json.dumps(p["name"]), p["rest"],
                ", ".join("{ g24: %s, g12: %s }" % (json.dumps(rects(f24)), json.dumps(rects(f12))) for f24, f12 in p["frames"]))
                for p in parts)
            entry += "]"
        lines.append(entry + " },")
    lines[-1] = lines[-1].rstrip(",")
    lines += ["}", ""]
    with open(os.path.join(ROOT, "components", "Pixels.js"), "w") as f:
        f.write("\n".join(lines))
    print("wrote components/Pixels.js with %d icons" % len(out))


if __name__ == "__main__":
    main()
