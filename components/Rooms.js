.pragma library

// The Rooms look's pure logic, kept free of QML so tests/rooms.test.js can
// run it under node: room tones, the block face and the pixel type, the cells
// of a meter, the decode and the prompt's reveal. Batteries
// 2.8 set the look and Sonus 1.8 carried it; this is their code with ROG
// Deck's icons. Icons are names in Pixels.js (pixel art). The panel kit is
// handed Nerd Font glyphs, which Glyph.qml swaps for their pixel icons
// through PIXEL_GLYPHS.

function hasLevel(level) {
  return level !== null && level !== undefined && !isNaN(level)
}

// ------------------------------------------------------------------ icons

// Every pixel icon the QML names outside the model, for the test that checks
// they all exist in Pixels.js.
var UI_PIXELS = ["chevron-down", "settings-cog", "arrow-left", "check", "fire", "fan", "cpu",
  "chevron-left", "chevron-right", "reload"]

// The Nerd Font glyphs ROG Deck hands the panel kit, each with its pixel
// icon. Glyph.qml draws the pixel icon for any glyph listed here, so the
// kit's icons match the rooms'. Code points, because a Nerd Font character is
// invisible in most editors. tests/rooms.test.js checks every glyph in the
// QML and the model is here.
var GLYPH_PIXELS = [
  [0xF0026, "warning-diamond"],  // alert
  [0xF0709, "reload"],           // restart to finish a GPU switch
  [0xF032A, "leaf"],             // Silent, Integrated, battery saver
  [0xF029A, "speed-medium"],     // Balanced
  [0xF04C5, "speed-fast"],       // Turbo, Dedicated
  [0xF0379, "monitor"],          // screen
  [0xF08AE, "gpu"],              // NVIDIA
  [0xF0FB2, "gpu"],              // NVIDIA state
  [0xF0210, "fan"],
  [0xF050F, "thermometer"],
  [0xF0EE0, "cpu"],              // package power
  [0xF0079, "battery-full"],
  [0xF0084, "zap"],              // charging
  [0xF0085, "battery-full"],     // charge once
  [0xF033E, "lock"],             // FN-lock, the power helper
  [0xF030C, "keyboard"],
  [0xF15FC, "matrix"],           // AniMe Matrix
  [0xF00DE, "sun"],              // brightness
  [0xF00DF, "sun"],
  [0xF051B, "clock"],            // auto-off
  [0xF06A5, "plug"],             // stay on while plugged in
  [0xF0E0C, "colors-swatch"],    // follow the theme
  [0xF0425, "power-off"],        // shutdown
  [0xF0426, "power-off"],        // turn off
  [0xF04B2, "bed"],              // sleep
  [0xF14DE, "power"],            // startup
  [0xF05A8, "sun"],              // awake
  [0xF0322, "lock"],             // lid closed
  [0xF040A, "sparkles"],         // animations
  [0xF03D8, "sparkles"],         // effect, RGB keyboard
  [0xF0208, "eye"],              // the ROG logo
  [0xF0284, "binary"],           // the banner
  [0xF057E, "volume-2"],         // boot sound
  [0xF035C, "layout"],           // show in the bar
  [0xF006A, "reload"],           // Auto refresh rate
  [0xF140B, "sliders-horizontal"], // custom curve
  [0xF0453, "undo"],             // reset
  [0xF0141, "chevron-left"],
  [0xF0142, "chevron-right"],
  [0xF012A, "snowflake"],        // the Cool preset
  [0xF0493, "settings-cog"],
  [0xF0156, "close"],
  [0xF012C, "check"],
  [0xF01DA, "download"],
  [0xF06B0, "download"],         // update
  [0xF051F, "clock"],            // check for updates
  [0xF0056, "arrow-left"],
  [0xF05A9, "wifi"]
]

var PIXEL_GLYPHS = {}
;(function() {
  for (var i = 0; i < GLYPH_PIXELS.length; i++) PIXEL_GLYPHS[String.fromCodePoint(GLYPH_PIXELS[i][0])] = GLYPH_PIXELS[i][1]
})()

function pixelFor(glyph) {
  return PIXEL_GLYPHS[glyph] || ""
}

// ------------------------------------------------------------ room tones

// The named colours in a theme's colors.toml: { red: "#565d60", ... }.
function parsePalette(text) {
  var out = {}
  String(text || "").split("\n").forEach(function(line) {
    var m = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
    if (m) out[m[1]] = m[2]
  })
  return out
}

// Contrast between two colours ({r, g, b}, 0 to 1), by the WCAG formula.
function contrast(a, b) {
  function lum(c) {
    function ch(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b)
  }
  var la = lum(a), lb = lum(b)
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
}

// Each tone's own hue, DailyDash's, for themes whose palette is all greys.
var TONE_HUES = {
  blue: "#5ab4f5",
  magenta: "#c38af0",
  cyan: "#4fc9d9",
  green: "#5cc98a",
  yellow: "#f1b467"
}

function hexRgb(hex) {
  var m = String(hex || "").match(/^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i)
  return m ? { r: parseInt(m[1], 16) / 255, g: parseInt(m[2], 16) / 255, b: parseInt(m[3], 16) / 255 } : null
}

function rgbHex(c) {
  function h(v) { var s = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16); return s.length < 2 ? "0" + s : s }
  return "#" + h(c.r) + h(c.g) + h(c.b)
}

// HSL saturation, 0 to 1.
function saturation(c) {
  var max = Math.max(c.r, c.g, c.b), min = Math.min(c.r, c.g, c.b)
  var l = (max + min) / 2
  if (max === min) return 0
  return (max - min) / (1 - Math.abs(2 * l - 1))
}

// A room's tone: the theme's colour of that name when it is a colour, else
// the tone's own hue, either way softened toward the theme's text colour so
// it sits quietly in the theme. No name is the text colour itself.
function roomToneHex(name, palette, foreground) {
  var fg = hexRgb(foreground) || { r: 0.8, g: 0.8, b: 0.8 }
  if (!name) return rgbHex(fg)
  var own = hexRgb(palette ? palette[name] : null)
  var base = own && saturation(own) >= 0.3 ? own : hexRgb(TONE_HUES[name] || TONE_HUES.green)
  var k = 0.3
  return rgbHex({ r: base.r + (fg.r - base.r) * k, g: base.g + (fg.g - base.g) * k, b: base.b + (fg.b - base.b) * k })
}

// ------------------------------------------------------------ block face

// Numbers in a three-row block face, as seven segments: the top and the
// middle bar ride the upper half of their row, so the digit sits two and a
// half rows tall. Returns the three rows; anything unknown is a dash.
var SEGMENTS = {
  "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fbgc",
  "5": "afgcd", "6": "afgecd", "7": "abc", "8": "abcdefg", "9": "abcdfg", "-": "g"
}

// A decimal point: one column, a block on the baseline (a fan's 4.3k).
var BIG_DOT = [" ", " ", "▀"]

// A one on the right-hand segments alone reads as a stray bar beside its
// neighbour, so it stands in the middle on a foot.
var BIG_ONE = ["▀█ ", " █ ", "▀▀▀"]

function bigDigits(text) {
  var rows = ["", "", ""]
  String(text).split("").forEach(function(ch, i) {
    var gap = i > 0 ? " " : ""
    if (ch === "1") {
      for (var r = 0; r < 3; r++) rows[r] += gap + BIG_ONE[r]
      return
    }
    if (ch === ".") {
      for (var d = 0; d < 3; d++) rows[d] += gap + BIG_DOT[d]
      return
    }
    var s = SEGMENTS[ch] === undefined ? SEGMENTS["-"] : SEGMENTS[ch]
    function on(seg) { return s.indexOf(seg) !== -1 }
    rows[0] += gap + (on("f") ? "█" : on("a") ? "▀" : " ") + (on("a") ? "▀" : " ") + (on("b") ? "█" : on("a") ? "▀" : " ")
    rows[1] += gap + (on("e") ? "█" : on("g") ? "▀" : " ") + (on("g") ? "▀" : " ") + (on("c") ? "█" : on("g") ? "▀" : " ")
    // Without a bottom bar (4, 7) the sides still reach the baseline.
    rows[2] += gap + (on("d") ? "▀▀▀" : (on("e") ? "▀" : " ") + " " + (on("c") ? "▀" : " "))
  })
  return rows
}

// ------------------------------------------------------------- pixel type

// Small numbers in the block face, as pixels: each digit is the face's
// columns by five half rows (bigDigits) with its middle column doubled, four
// wide, so the inside of a 0 or an 8 is two pixels and reads at bar size. The
// one keeps a single stem. The rest is drawn to match, one-cell strokes and
// square corners: the units ROG Deck writes beside a figure (° W Hz k) and
// what the bar says of a sleeping GPU (Zz, off). Rows top to bottom, "#" on.
var PIXEL_FONT = {
  "1": [".##.", "..#.", "..#.", "..#.", ".###"],
  "%": ["##..#", "##.#.", "..#..", ".#.##", "#..##"],
  " ": ["..", "..", "..", "..", ".."],
  ".": [".", ".", ".", ".", "#"],
  "°": ["###", "#.#", "###", "...", "..."],
  "W": ["#...#", "#...#", "#.#.#", "#.#.#", ".#.#."],
  "H": ["#..#", "#..#", "####", "#..#", "#..#"],
  "z": ["....", "####", "..#.", ".#..", "####"],
  "Z": ["####", "..#.", ".#..", "#...", "####"],
  "k": ["#...", "#..#", "#.#.", "###.", "#..#"],
  "o": ["....", "####", "#..#", "#..#", "####"],
  "f": [".##", "#..", "###", "#..", "#.."]
}
;(function() {
  "023456789-".split("").forEach(function(ch) {
    var rows = bigDigits(ch)
    var half = []
    rows.forEach(function(row) {
      var top = "", bottom = ""
      for (var i = 0; i < row.length; i++) {
        var c = row.charAt(i)
        var t = c === "█" || c === "▀" ? "#" : "."
        var u = c === "█" || c === "▄" ? "#" : "."
        // The middle column twice.
        top += i === 1 ? t + t : t
        bottom += i === 1 ? u + u : u
      }
      half.push(top, bottom)
    })
    PIXEL_FONT[ch] = half.slice(0, 5)
  })
})()

// A line in the pixel type: { width, height, rects }, in cells, rects as
// [x, y, w, h] merged along each row. A cell between letters; anything the
// type lacks is skipped.
function pixelText(text) {
  var rects = [], x = 0
  String(text || "").split("").forEach(function(ch) {
    var glyph = PIXEL_FONT[ch]
    if (!glyph) return
    if (x > 0) x += 1
    for (var r = 0; r < glyph.length; r++) {
      var row = glyph[r], c = 0
      while (c < row.length) {
        if (row.charAt(c) !== "#") { c++; continue }
        var start = c
        while (c < row.length && row.charAt(c) === "#") c++
        rects.push([x + start, r, c - start, 1])
      }
    }
    x += glyph[0].length
  })
  return { width: x, height: 5, rects: rects }
}

// Whether the pixel type can draw all of `text`.
function drawable(text) {
  return String(text).split("").every(function(ch) { return PIXEL_FONT[ch] !== undefined })
}

// --------------------------------------------------------------- meters

// A level drawn as a meter of cells, the way Batteries draws a battery: ten
// cells for a tenth each, so it can be counted at a glance. For each cell,
// how full it is (0..1), how lit (`glow`, 0..1: a ripple passing), how far
// the pointer presses it (`press`, 0..1).
//
// opts: segments, level (0..100, fractional while it fills in), dent (0..1
// across the body, where the pointer is) and ripples ([{ x, age }], x 0..1
// across, age in ms).
var METER = {
  RIPPLE_MS: 760,      // Weave's ripple
  RIPPLE_CELLS: 14,    // how far it travels, in cells
  DENT_CELLS: 1.6      // how wide the pointer presses, in cells
}

function meterCells(opts) {
  var n = Math.max(1, Math.floor(opts.segments || 10))
  var level = hasLevel(opts.level) ? Math.max(0, Math.min(100, opts.level)) : 0
  var full = level / 100 * n
  var ripples = opts.ripples || []
  var out = []
  for (var i = 0; i < n; i++) {
    var fill = Math.max(0, Math.min(1, full - i))
    var glow = 0
    for (var j = 0; j < ripples.length; j++) {
      var k = ripples[j].age / METER.RIPPLE_MS
      if (k < 0 || k >= 1) continue
      var d = Math.abs(i + 0.5 - ripples[j].x * n)
      var ring = 1 - Math.abs(d - k * Math.min(METER.RIPPLE_CELLS, n * 1.4)) / 1.1
      if (ring > 0) glow = Math.max(glow, ring * (1 - k))
    }
    var press = 0
    if (opts.dent !== null && opts.dent !== undefined)
      press = Math.max(0, 1 - Math.abs(i + 0.5 - opts.dent * n) / METER.DENT_CELLS)
    out.push({ fill: fill, glow: glow, press: press })
  }
  return out
}

// Where a press on a fader lands, as a value from `from` to `to` snapped to
// `step`: x across a meter `width` wide, and never under `floor`, the
// smallest value it may be set to (a charge limit stops at 20).
function faderValue(x, width, from, to, step, floor) {
  if (!(width > 0) || !(to > from)) return from
  var v = from + Math.max(0, Math.min(1, x / width)) * (to - from)
  var s = step > 0 ? step : 1
  v = from + Math.round((v - from) / s) * s
  if (floor !== undefined && floor !== null) v = Math.max(floor, v)
  return Math.max(from, Math.min(to, v))
}

// Which cell a press at x lands in, counted from 1: anywhere in a cell, the
// gaps between them included, picks it. A press past either end picks the
// end cell.
function cellAt(x, width, segments) {
  var n = Math.max(1, Math.floor(segments || 1))
  if (!(width > 0)) return 1
  return Math.max(1, Math.min(n, Math.floor(x / width * n) + 1))
}

// ---------------------------------------------------------------- prompt

function escapeHtml(text) {
  return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

// The prompt line `typed` characters in, as styled text that always lays out
// the whole line plus a cursor cell, the part not typed yet drawn clear, so a
// word never wraps differently while it types. The cursor stands in for the
// next character, except a space, which it would glue to the next word; once
// typed, it blinks in the cell kept for it at the end.
var CURSOR = "▌"
var CLEAR = "<font color=\"#00000000\">"

function revealLine(line, typed, cursorOn) {
  line = String(line || "")
  var n = Math.max(0, Math.min(line.length, Math.floor(typed) || 0))
  var shown = escapeHtml(line.substring(0, n))
  var rest
  if (n < line.length) {
    var next = line.charAt(n)
    shown += next === " " ? " " : CURSOR
    rest = line.substring(n + 1) + CURSOR
  } else if (cursorOn) {
    shown += CURSOR
    rest = ""
  } else {
    rest = CURSOR
  }
  return rest === "" ? shown : shown + CLEAR + escapeHtml(rest) + "</font>"
}

// ---------------------------------------------------------------- motion

// How the icons move is in Motion.js.

// Text arriving the way a terminal decodes it: the first `progress` of it
// is real, the rest cycles through glyphs. Spaces and separators stay put so
// the line keeps its shape. `seed` varies the noise between runs.
var GLITCH = "#%&*+=<>/\\|~:;?!$@"

function scramble(text, progress, seed) {
  text = String(text || "")
  var keep = Math.floor(Math.max(0, Math.min(1, progress)) * text.length)
  var tick = Math.floor(progress * 14)
  var out = ""
  for (var i = 0; i < text.length; i++) {
    var ch = text.charAt(i)
    if (i < keep || ch === " " || ch === "·") { out += ch; continue }
    var h = (((i + 1) * 73856093) ^ (((seed || 0) + 1) * 19349663) ^ ((tick + 1) * 83492791)) >>> 0
    out += GLITCH.charAt(h % GLITCH.length)
  }
  return out
}
