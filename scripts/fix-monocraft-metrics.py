#!/usr/bin/env python3
"""
Give the bundled Monocraft (assets/fonts) line boxes with room in them.

Monocraft 4.2.1 sets USE_TYPO_METRICS with a typo ascender of 960 and a
descender of 120 on its 1080 em, so Qt makes every line exactly one em tall:
capitals (840) and descenders (120) fill it, lines sit one font pixel apart,
and the bold's descenders (144) poke out of their line. This sets the line
box to 1080 over the baseline and 240 under it (1.22 em, about what the
panel was laid out for), which centres the capitals in the box and leaves
three font pixels between lines. Only the vertical metrics change; every
glyph is as Monocraft draws it. The font is under the SIL OFL 1.1, which
names no Reserved Font Name, so the changed copy keeps its name.

Run from the repo root, on the files as released:

    python3 scripts/fix-monocraft-metrics.py
"""

import os
import sys

from fontTools.ttLib import TTFont

sys.dont_write_bytecode = True

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ASCENT, DESCENT = 1080, 240

for name in ("Monocraft.ttf", "Monocraft-Bold.ttf"):
    path = os.path.join(ROOT, "assets", "fonts", name)
    font = TTFont(path)
    os2, hhea = font["OS/2"], font["hhea"]
    os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = ASCENT, -DESCENT, 0
    hhea.ascent, hhea.descent, hhea.lineGap = ASCENT, -DESCENT, 0
    font.save(path)
    print("%s: line box %d over the baseline, %d under" % (name, ASCENT, DESCENT))
