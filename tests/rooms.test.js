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
  "faderValue", "revealLine", "STORIES", "storyOf", "storyPose", "spinFrame", "spinInterval", "scramble"])
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
// The modes' CPU cores grow from Silent to Turbo, so the bar icon says which.
const modeCells = Model.PROFILES.map(p => cellsOf(icons[p.pixel]))
assert.ok(modeCells[0] < modeCells[1] && modeCells[1] < modeCells[2], "the core grows with the mode")
// The fan's two frames are the same weight, so flipping them reads as a turn.
assert.ok(Math.abs(cellsOf(icons.fan) - cellsOf(icons["fan-2"])) <= 4, "the fan's frames match in weight")

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

// ---- motion

for (const story of new Set(Object.values(Rooms.STORIES).concat(["tilt", "buzz", "pop"]))) {
  assert.deepStrictEqual(Rooms.storyPose(story, 0), { x: 0, y: 0 }, story + " starts at rest")
  assert.deepStrictEqual(Rooms.storyPose(story, 1), { x: 0, y: 0 }, story + " ends where it began")
  for (let k = 0; k < 1; k += 0.05) {
    const p = Rooms.storyPose(story, k)
    assert.ok(Number.isInteger(p.x) && Number.isInteger(p.y), story + " moves in whole pixels")
  }
}
assert.strictEqual(Rooms.spinFrame(0), 0)
assert.strictEqual(Rooms.spinFrame(1), 0)
assert.strictEqual(Rooms.spinFrame(0.999), 0, "the spin ends on the frame it began on")
assert.ok([0.1, 0.2, 0.3, 0.4, 0.5].some(k => Rooms.spinFrame(k) === 1), "the spin turns")
assert.strictEqual(Rooms.spinInterval(0), 0, "still fans hold still")
assert.strictEqual(Rooms.spinInterval(null), 0)
assert.ok(Rooms.spinInterval(6000) < Rooms.spinInterval(2000), "faster fans turn faster")
assert.ok(Rooms.spinInterval(20000) >= 140)

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
