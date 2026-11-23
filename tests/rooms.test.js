// Run with: node tests/rooms.test.js
// The Rooms look: components/Rooms.js, the icons in components/Pixels.js,
// and what the QML and the model ask of them.
const fs = require("fs")
const path = require("path")
const assert = require("assert")

const root = path.join(__dirname, "..")
function load(file, names) {
  const source = fs.readFileSync(path.join(root, file), "utf8").replace(/^\.pragma library\s*/, "")
  return new Function(source + "\nreturn { " + names.join(", ") + " }")()
}

const Rooms = load("components/Rooms.js", ["hasLevel", "UI_PIXELS", "GLYPH_PIXELS", "PIXEL_GLYPHS", "pixelFor", "parsePalette",
  "contrast", "TONE_HUES", "hexRgb", "roomToneHex", "bigDigits", "PIXEL_FONT", "pixelText", "drawable", "METER", "meterCells",
  "faderValue", "revealLine", "scramble"])
const Motion = load("components/Motion.js", ["LOOP_MS", "REST", "STORIES", "hasStory", "duration", "poseAt", "loopAt",
  "SPIN_STEPS", "spinInterval"])
const Model = load("Model.js", ["MODEL_PIXELS", "PROFILES", "GPU_MODES", "FAN_PRESETS", "ANIME_CONTENT", "ROOM_TONES",
  "barParts", "hoverRows", "batteryPixel"])
const { icons } = load("components/Pixels.js", ["icons"])

// ---- icons

const qmlFiles = ["Panel.qml", "Service.qml"].map(f => path.join(root, f))
  .concat(fs.readdirSync(path.join(root, "components")).filter(f => f.endsWith(".qml")).map(f => path.join(root, "components", f)))

// Every pixel icon the QML, the model and the glyph map name is in
// Pixels.js, on both grids.
const named = new Set([].concat(Rooms.UI_PIXELS, Model.MODEL_PIXELS, Rooms.GLYPH_PIXELS.map(p => p[1]),
  Model.PROFILES.map(p => p.pixel), Model.GPU_MODES.map(m => m.pixel), Model.FAN_PRESETS.map(p => p.pixel),
  Model.ANIME_CONTENT.map(c => c.pixel)))
for (const file of qmlFiles) {
  const text = fs.readFileSync(file, "utf8")
  for (const m of text.matchAll(/\b(?:name|icon|mark|pixel):\s*"([a-z0-9-]+)"/g)) named.add(m[1])
  for (const m of text.matchAll(/frames:\s*\[([^\]]*)\]/g))
    for (const n of m[1].matchAll(/"([a-z0-9-]+)"/g)) named.add(n[1])
}
for (const name of named) {
  assert.ok(icons[name], name + " is in Pixels.js")
  assert.ok(icons[name].g24.length > 0 && icons[name].g12.length > 0, name + " has both grids")
}
// Every rect is on the grid, in whole cells.
for (const [name, art] of Object.entries(icons)) {
  for (const [grid, size] of [["g24", 24], ["g12", 12]]) {
    for (const r of art[grid]) {
      assert.ok(r.every(Number.isInteger), name + " " + grid + " is in whole cells")
      assert.ok(r[0] >= 0 && r[1] >= 0 && r[0] + r[2] <= size && r[1] + r[3] <= size, name + " " + grid + " stays on its grid")
    }
  }
}
const cellsOf = art => art.g12.reduce((n, r) => n + r[2] * r[3], 0)
// The CPU reads as a chip at twelve pixels: a square body with pins on all
// four sides (Pixelarticons' own reads as a sun there).
const chip = icons.cpu.g12
assert.ok(chip.some(r => r[1] === 0) && chip.some(r => r[0] === 0) && chip.some(r => r[1] + r[3] === 12) && chip.some(r => r[0] + r[2] === 12),
  "the CPU has pins reaching every side")
assert.ok(cellsOf(icons.cpu) <= 48, "and room between them, or at twelve pixels it reads as a sun")
// The fan's two blade frames are the same weight, so flipping them reads as
// a turn.
const blades = icons.fan.parts.find(p => p.name === "blades").frames.map(f => f.g12.reduce((n, r) => n + r[2] * r[3], 0))
assert.ok(Math.abs(blades[0] - blades[1]) <= 4, "the fan's frames match in weight")

// Every Nerd Font glyph handed to the panel kit has a pixel icon, so no
// typed glyph stands among the pixel art. The one the kit types itself, the
// "Check now" button inside UpdateSection, is the known exception.
const glyphFiles = qmlFiles.concat([path.join(root, "Model.js"), path.join(root, "components", "Update.js")])
const exempt = new Set([0xF0453])
for (const file of glyphFiles) {
  if (/UpdateSection\.qml$/.test(file)) continue
  const text = fs.readFileSync(file, "utf8")
  for (const ch of text) {
    const cp = ch.codePointAt(0)
    if ((cp >= 0xE000 && cp <= 0xF8FF) || (cp >= 0xF0000 && cp <= 0xFFFFD)) {
      if (exempt.has(cp)) continue
      assert.ok(Rooms.pixelFor(ch), "U+" + cp.toString(16).toUpperCase() + " in " + path.basename(file) + " has a pixel icon")
    }
  }
}
assert.strictEqual(Rooms.pixelFor("x"), "")

// ---- tones

const palette = Rooms.parsePalette('blue = "#7a99a8"\nred="#565d60"\n  green = "#5ab4f5" # comment\nnot a colour\n')
assert.deepStrictEqual(palette, { blue: "#7a99a8", red: "#565d60", green: "#5ab4f5" })
for (const name of new Set(Object.values(Model.ROOM_TONES))) {
  assert.ok(Rooms.TONE_HUES[name], name + " has a hue of its own")
  for (const fg of ["#cacccc", "#1a1a1a"])
    assert.match(Rooms.roomToneHex(name, palette, fg), /^#[0-9a-f]{6}$/, name + " is a colour")
}
// A grey in the theme gives way to the tone's own hue.
const grey = Rooms.roomToneHex("blue", { blue: "#777777" }, "#ffffff")
const own = Rooms.roomToneHex("blue", {}, "#ffffff")
assert.strictEqual(grey, own)
assert.strictEqual(Rooms.roomToneHex("", palette, "#cacccc"), "#cacccc", "no tone is the text colour")
assert.ok(Rooms.contrast(Rooms.hexRgb("#ffffff"), Rooms.hexRgb("#000000")) > 20)

// ---- block face and pixel type

assert.deepStrictEqual(Rooms.bigDigits("1"), ["▀█ ", " █ ", "▀▀▀"])
assert.strictEqual(Rooms.bigDigits("165")[0].length, 11)
assert.deepStrictEqual(Rooms.bigDigits("x"), Rooms.bigDigits("-"))
assert.deepStrictEqual(Rooms.bigDigits("4.3").map(r => r.length), [9, 9, 9], "a decimal point is one column")
assert.strictEqual(Rooms.bigDigits("4.3")[2].charAt(4), "▀", "it sits on the baseline")
for (const ch of Object.keys(Rooms.PIXEL_FONT)) {
  const glyph = Rooms.PIXEL_FONT[ch]
  assert.strictEqual(glyph.length, 5, JSON.stringify(ch) + " is five rows")
  assert.ok(glyph.every(r => r.length === glyph[0].length), JSON.stringify(ch) + " rows are even")
}
assert.deepStrictEqual(Rooms.pixelText("1"), { width: 4, height: 5, rects: [[1, 0, 2, 1], [2, 1, 1, 1], [2, 2, 1, 1], [2, 3, 1, 1], [1, 4, 3, 1]] })

// Every unit a figure writes, and everything the bar and the hover card
// write, can be drawn in the pixel type.
for (const unit of ["%", "°", "W", "Hz"]) assert.ok(Rooms.drawable(unit), unit + " can be drawn")
const statuses = [
  { asusd: true, ac: true, profile: { active: "performance" }, temps: { cpu: 104.6, gpu: 99 }, watts: { igpu: 65.2, dgpu: 140.4 },
    fans: { cpu: 6900, gpu: 7100 }, battery: { percent: 100, limit: 100 }, dgpu: "active", display: { refresh: 240 } },
  { asusd: true, ac: false, profile: { active: "power-saver" }, temps: { cpu: 41, gpu: null }, watts: { igpu: 3.04, dgpu: null },
    fans: { cpu: 0, gpu: 0 }, battery: { percent: 7, limit: 80 }, dgpu: "suspended", display: { refresh: 60 } },
  { asusd: true, ac: false, profile: { active: "balanced" }, temps: { cpu: 55 }, watts: {}, fans: { cpu: 850, gpu: null },
    battery: { percent: 50 }, dgpu: "absent", display: { refresh: 120 } }
]
const stats = ["mode", "cpuTemp", "gpuTemp", "fans", "power", "dgpu", "battery", "refresh"]
for (const st of statuses) {
  for (const part of Model.barParts(st, stats)) {
    assert.ok(Rooms.drawable(part.text), JSON.stringify(part.text) + " can be drawn in the bar")
    if (part.icon) assert.ok(icons[part.icon], part.icon + " is a pixel icon")
  }
  for (const row of Model.hoverRows(st, {})) {
    assert.ok(Rooms.drawable(row.figure), JSON.stringify(row.figure) + " can be drawn in the hover card")
    assert.ok(icons[row.icon], row.icon + " is a pixel icon")
    if (row.mark) assert.ok(icons[row.mark], row.mark + " is a pixel icon")
    assert.ok(Rooms.TONE_HUES[row.tone], row.key + " has a tone")
  }
}

// ---- meters and faders

const cells = Rooms.meterCells({ segments: 10, level: 45 })
assert.deepStrictEqual(cells.map(c => c.fill), [1, 1, 1, 1, 0.5, 0, 0, 0, 0, 0])
assert.ok(Rooms.meterCells({ segments: 10, level: 50, dent: 0.05 })[0].press > 0.5)
assert.ok(Rooms.meterCells({ segments: 10, level: 50, ripples: [{ x: 0.5, age: 100 }] }).some(c => c.glow > 0))
assert.ok(Rooms.meterCells({ segments: 10, level: 50, ripples: [{ x: 0.5, age: 900 }] }).every(c => c.glow === 0), "a ripple runs out")
assert.deepStrictEqual(Rooms.meterCells({ segments: 3, level: null }).map(c => c.fill), [0, 0, 0])
// The keyboard: three cells, the left edge off.
assert.strictEqual(Rooms.faderValue(2, 300, 0, 3, 1), 0)
assert.strictEqual(Rooms.faderValue(160, 300, 0, 3, 1), 2)
assert.strictEqual(Rooms.faderValue(400, 300, 0, 3, 1), 3)
// The charge limit: drawn from 0, set in fives, never under 20.
assert.strictEqual(Rooms.faderValue(30, 300, 0, 100, 5, 20), 20)
assert.strictEqual(Rooms.faderValue(240, 300, 0, 100, 5, 20), 80)
// The CPU limit in watts.
assert.strictEqual(Rooms.faderValue(150, 300, 15, 35, 1), 25)

// ---- text

// Every text ROG Deck draws itself is a MonoText: Monocraft unsmoothed, so its
// strokes land on whole device pixels. The panel kit's files are shared with
// the other plugins and keep their own; BigFigure's hidden "0000000000" only
// measures the bar font, and Glyph's Text types a glyph with no pixel icon.
const KIT = ["SectionHeader", "StatTile", "ToggleTile", "SwitchRow", "Seg", "Notice", "LevelBar", "OptionRow", "Caption", "UpdateSection"]
const PLAIN_TEXT_OK = { "BigFigure.qml": 1, "Glyph.qml": 1, "MonoText.qml": 1 }
for (const file of qmlFiles) {
  const base = path.basename(file)
  if (KIT.includes(base.replace(".qml", ""))) continue
  const plain = (fs.readFileSync(file, "utf8").match(/^\s*Text \{/gm) || []).length
  assert.strictEqual(plain, PLAIN_TEXT_OK[base] || 0, base + " draws its text with MonoText")
}

// ---- motion

// An icon's cells as a set of "x,y" on one grid.
function cellSet(rects) {
  const out = new Set()
  for (const [x, y, w, h] of rects) for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) out.add((x + i) + "," + (y + j))
  return out
}
for (const [name, art] of Object.entries(icons)) {
  // Every icon acts itself out.
  assert.ok(Motion.hasStory(name), name + " has a story in Motion.js")
  if (!art.parts) continue
  // At rest an icon split into parts draws exactly its art: its base and
  // each part's resting frame, on both grids, nothing drawn twice.
  for (const grid of ["g24", "g12"]) {
    const whole = cellSet(art[grid])
    const drawn = cellSet(art.base[grid])
    let count = drawn.size
    for (const part of art.parts) {
      assert.ok(part.rest >= 0 && part.rest < part.frames.length, name + " " + part.name + " rests on a frame it has")
      for (const c of cellSet(part.frames[part.rest][grid])) { drawn.add(c); count++ }
    }
    assert.strictEqual(count, drawn.size, name + " " + grid + ": no cell is drawn twice at rest")
    assert.deepStrictEqual([...drawn].sort(), [...whole].sort(), name + " " + grid + ": base and resting parts are the icon")
  }
}
for (const name of Object.keys(Motion.STORIES)) {
  const art = icons[name]
  assert.ok(art, name + "'s story is for an icon in Pixels.js")
  const parts = new Map((art.parts || []).map(p => [p.name, p]))
  assert.deepStrictEqual(Motion.poseAt(name, 0), Motion.REST, name + " starts at rest")
  assert.deepStrictEqual(Motion.poseAt(name, 1), Motion.REST, name + " ends at rest")
  let moved = false
  for (let k = 0.01; k < 1; k += 0.01) {
    const p = Motion.poseAt(name, k)
    assert.ok(Number.isInteger(p.x) && Number.isInteger(p.y), name + " moves in whole cells")
    assert.ok(p.turn % 45 === 0, name + " turns only in eighths")
    if (p.x || p.y || p.turn || p.hide) moved = true
    for (const [partName, q] of Object.entries(p.parts)) {
      const part = parts.get(partName)
      assert.ok(part, name + " moves a part it has: " + partName)
      if (q.x !== undefined) assert.ok(Number.isInteger(q.x), name + " " + partName + " moves in whole cells")
      if (q.y !== undefined) assert.ok(Number.isInteger(q.y), name + " " + partName + " moves in whole cells")
      if (q.f !== undefined) assert.ok(Number.isInteger(q.f) && q.f >= 0 && q.f < part.frames.length, name + " " + partName + " shows a frame it has")
      if (q.x || q.y || q.hide || (q.f !== undefined && q.f !== part.rest)) moved = true
    }
  }
  assert.ok(moved, name + "'s story moves something")
  // Back at rest well before the end, so the last frame is never cut off.
  const late = Motion.poseAt(name, 0.99)
  assert.strictEqual(late.x || late.y || late.hide ? 1 : 0, 0, name + " is still by the end")
  for (const [partName, q] of Object.entries(late.parts)) {
    assert.ok(!q.x && !q.y && !q.hide && (q.f === undefined || q.f === parts.get(partName).rest), name + " " + partName + " is home by the end")
  }
  assert.ok(late.turn % 90 === 0, name + " ends on a quarter turn, which looks as it began")
}
// Loops run off the one shared clock: every period divides it.
for (const step of Motion.SPIN_STEPS) assert.strictEqual(Motion.LOOP_MS % (2 * step), 0, "a spin of " + step + " ms comes round with the clock")
for (const every of [2400, 4800]) assert.strictEqual(Motion.LOOP_MS % every, 0)
assert.deepStrictEqual(Motion.loopAt("fan", "spin", 200, 0), Motion.loopAt("fan", "spin", 200, Motion.LOOP_MS), "the spin wraps cleanly")
assert.deepStrictEqual(Motion.loopAt("thermometer", "burst", 2400, 0), Motion.REST, "a burst starts at rest")
assert.deepStrictEqual(Motion.loopAt("thermometer", "burst", 2400, 2000), Motion.REST, "and rests between bursts")
assert.notDeepStrictEqual(Motion.loopAt("thermometer", "burst", 2400, 300), Motion.REST, "and moves in them")
assert.strictEqual(Motion.spinInterval(0), 0, "still fans hold still")
assert.strictEqual(Motion.spinInterval(null), 0)
assert.ok(Motion.spinInterval(6000) < Motion.spinInterval(2000), "faster fans turn faster")
assert.ok(Motion.SPIN_STEPS.includes(Motion.spinInterval(4300)))

const noise = Rooms.scramble("CPU · 4.1k rpm", 0.3, 2)
assert.strictEqual(noise.length, "CPU · 4.1k rpm".length)
assert.strictEqual(noise.charAt(5), " ")
assert.strictEqual(noise.charAt(4), "·")
assert.strictEqual(Rooms.scramble("Held", 1, 0), "Held")

// The prompt lays out the whole line from the first character.
assert.strictEqual(Rooms.revealLine("ab", 0, true), "▌<font color=\"#00000000\">b▌</font>")
assert.strictEqual(Rooms.revealLine("a b", 1, true), "a <font color=\"#00000000\">b▌</font>")
assert.strictEqual(Rooms.revealLine("ab", 2, true), "ab▌")
assert.strictEqual(Rooms.revealLine("ab", 2, false), "ab<font color=\"#00000000\">▌</font>")
assert.strictEqual(Rooms.revealLine("<a&b>", 5, true), "&lt;a&amp;b&gt;▌")

console.log("rooms tests passed")
