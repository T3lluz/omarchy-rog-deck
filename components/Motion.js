.pragma library

// How every pixel icon acts itself out, after DailyDash's island glyphs:
// each icon does what its thing does. The flame flickers, the needle swings
// through its range, the fan's blades turn round a hub that stays put, the
// mercury climbs, the keys light up left to right. Only the part that moves
// moves (scripts/fetch-pixel-icons.py splits the art into parts and frames),
// and only in whole cells of the icon's 12-cell grid, so the art never
// smears. PixelIcon.qml plays it; this file is pure so tests/rooms.test.js
// can check it under node.
//
// A story is a one-off: `pose(name, k)` gives the icon's pose `k` of the way
// through (0..1), and every story starts and ends at rest. A loop (a fan
// spinning, a hot thermometer, a charging battery, a banner at work) runs
// off one shared clock of LOOP_MS, the wall clock folded, and every loop's
// period divides it, so nothing jumps when the clock comes round.

var LOOP_MS = 4800

// A pose: the whole icon's offset in cells, its turn in degrees and whether
// it shows, and each moving part's offset, frame (`f`, its index in the
// part's frames; unset rests) and whether it shows.
var REST = { x: 0, y: 0, turn: 0, hide: false, parts: {} }

// The value of a stepped track at `k`: the last [time, value] at or before
// it. Pixel art moves in steps, not glides, so there is nothing between.
function track(k, steps) {
  var v = steps[0][1]
  for (var i = 0; i < steps.length; i++) if (steps[i][0] <= k) v = steps[i][1]
  return v
}

// Hidden while `k` is in any of the [from, to) windows.
function off(k, windows) {
  for (var i = 0; i < windows.length; i++) if (k >= windows[i][0] && k < windows[i][1]) return true
  return false
}

// Parts numbered prefix0..prefix(n-1) drawing themselves in: all go dark at
// the start, then each comes back in order between `from` and `to`.
function drawIn(k, prefix, n, from, to, into) {
  var out = into || {}
  for (var i = 0; i < n; i++) {
    var back = from + (to - from) * i / Math.max(1, n - 1)
    if (k < back) out[prefix + i] = { hide: true }
  }
  return out
}

function pose(parts, whole) {
  var p = { x: 0, y: 0, turn: 0, hide: false, parts: parts || {} }
  if (whole) {
    if (whole.x) p.x = whole.x
    if (whole.y) p.y = whole.y
    if (whole.turn) p.turn = whole.turn
    if (whole.hide) p.hide = true
  }
  return p
}

// The battery's charge: the bars fill one by one, then fall back to where
// the icon has them. `rest` is the icon's own count.
function charge(rest) {
  return function(k) {
    return pose({ bars: { f: track(k, [[0, 0], [0.12, 1], [0.27, 2], [0.42, 3], [0.72, rest]]) } })
  }
}

// The dial's needle, `rest` being its own position (0 slow, 1 upright, 2 fast).
function swing(path) {
  return function(k) {
    return pose({ needle: { f: track(k, path) } })
  }
}

var STORIES = {
  // The mark: the flame's tip flickers while its heart leaps.
  fire: { ms: 900, at: function(k) {
    return pose({
      tip: { x: track(k, [[0, 0], [0.1, 1], [0.25, 0], [0.4, -1], [0.55, 0], [0.7, 1], [0.85, 0]]) },
      core: { y: track(k, [[0, 0], [0.15, -1], [0.35, 0], [0.6, -1], [0.8, 0]]) }
    })
  } },
  // The chip's pins pulse outward twice and the die blinks with them.
  cpu: { ms: 800, at: function(k) {
    var out = track(k, [[0, 0], [0.1, 1], [0.3, 0], [0.5, 1], [0.7, 0]])
    return pose({
      pinsN: { y: -out }, pinsS: { y: out }, pinsW: { x: -out }, pinsE: { x: out },
      die: { hide: off(k, [[0.15, 0.3], [0.55, 0.7]]) }
    })
  } },
  // The card's fans whirr up and wind down.
  gpu: { ms: 900, at: function(k) {
    return pose({ fans: { f: track(k, [[0, 0], [0.05, 1], [0.15, 0], [0.25, 1], [0.37, 0], [0.5, 1], [0.66, 0], [0.82, 1], [0.95, 0]]) } })
  } },
  // The mercury climbs the tube and sinks back.
  thermometer: { ms: 1100, at: function(k) {
    return pose({ mercury: { f: track(k, [[0, 0], [0.06, 1], [0.12, 2], [0.18, 3], [0.24, 4], [0.3, 5],
      [0.6, 4], [0.68, 3], [0.76, 2], [0.84, 1], [0.92, 0]]) } })
  } },
  // A line sweeps down the screen, as a refresh does.
  monitor: { ms: 700, at: function(k) {
    return pose({ scan: { f: track(k, [[0, 0], [0.05, 1], [0.18, 2], [0.31, 3], [0.44, 4], [0.57, 5], [0.7, 6], [0.85, 0]]) } })
  } },
  // The keys go dark and light up again from the left.
  keyboard: { ms: 800, at: function(k) { return pose(drawIn(k, "keys", 5, 0.15, 0.75)) } },
  // The lid's LEDs come on corner to corner.
  matrix: { ms: 900, at: function(k) { return pose(drawIn(k, "dots", 5, 0.15, 0.8)) } },
  // Silent: the leaf drifts down on the air and back.
  leaf: { ms: 1000, at: function(k) {
    return pose(null, {
      x: track(k, [[0, 0], [0.22, 1], [0.44, 0], [0.62, -1], [0.82, 0]]),
      y: track(k, [[0, 0], [0.1, 1], [0.82, 0]])
    })
  } },
  // Balanced: the needle drops back, swings past upright and settles.
  "speed-medium": { ms: 800, at: swing([[0, 1], [0.1, 0], [0.32, 1], [0.52, 2], [0.75, 1]]) },
  // Turbo: the needle drops back and revs up to fast, twice.
  "speed-fast": { ms: 800, at: swing([[0, 2], [0.1, 1], [0.2, 0], [0.38, 1], [0.52, 2], [0.66, 1], [0.8, 2]]) },
  // The blades turn round the hub, fast and slowing.
  fan: { ms: 900, at: function(k) {
    return pose({ blades: { f: track(k, [[0, 0], [0.06, 1], [0.14, 0], [0.24, 1], [0.36, 0], [0.5, 1], [0.66, 0], [0.84, 1], [0.97, 0]]) } })
  } },
  battery: { ms: 1000, at: charge(0) },
  "battery-medium": { ms: 1000, at: charge(2) },
  "battery-full": { ms: 1000, at: charge(3) },
  // Low: the last bar blinks.
  "battery-low": { ms: 900, at: function(k) {
    return pose({ bars: { f: track(k, [[0, 1], [0.1, 0], [0.3, 1], [0.5, 0], [0.7, 1]]) } })
  } },
  // A spark: the bolt flashes twice.
  zap: { ms: 600, at: function(k) { return pose(null, { hide: off(k, [[0.1, 0.22], [0.36, 0.48]]) }) } },
  // The plug lifts and seats itself.
  plug: { ms: 600, at: function(k) { return pose({ body: { y: track(k, [[0, 0], [0.12, -1], [0.55, 0]]) } }) } },
  // The shackle lifts and snaps shut.
  lock: { ms: 700, at: function(k) { return pose({ shackle: { y: track(k, [[0, 0], [0.1, -1], [0.55, 0]]) } }) } },
  // The rays flash in turn.
  sun: { ms: 900, at: function(k) {
    return pose({
      straight: { hide: off(k, [[0.08, 0.25], [0.45, 0.62]]) },
      slanted: { hide: off(k, [[0.25, 0.42], [0.62, 0.8]]) }
    })
  } },
  // A star twinkles beside the moon.
  moon: { ms: 1100, at: function(k) {
    return pose({ star: { f: track(k, [[0, 0], [0.08, 1], [0.2, 2], [0.45, 1], [0.55, 2], [0.75, 1], [0.88, 0]]) } })
  } },
  // The button is pressed in.
  power: { ms: 600, at: function(k) { return pose({ stem: { y: track(k, [[0, 0], [0.12, 1], [0.5, 0]]) } }) } },
  // The slash draws across.
  "power-off": { ms: 700, at: function(k) { return pose(drawIn(k, "slash", 5, 0.12, 0.7)) } },
  // A Z drifts up from the pillow.
  bed: { ms: 1100, at: function(k) {
    var shown = k >= 0.08 && k < 0.85
    return pose({ z: { f: shown ? 1 : 0, y: track(k, [[0, 0], [0.45, -1], [0.85, 0]]) } })
  } },
  // The minute hand goes round once.
  clock: { ms: 1000, at: function(k) {
    return pose({ minute: { f: track(k, [[0, 0], [0.15, 1], [0.35, 2], [0.55, 3], [0.75, 0]]) } })
  } },
  // A blink, then a glance one way and the other.
  eye: { ms: 1200, at: function(k) {
    var lid = track(k, [[0, 0], [0.06, 1], [0.12, 2], [0.22, 1], [0.28, 0]])
    return pose({
      lidTop: { y: lid }, lidBottom: { y: -lid },
      pupil: { hide: lid === 2, x: track(k, [[0, 0], [0.4, -1], [0.62, 1], [0.84, 0]]) }
    })
  } },
  // The bits flip, a digit at a time.
  binary: { ms: 800, at: function(k) {
    return pose({
      bit0: { hide: off(k, [[0.08, 0.26]]) }, bit3: { hide: off(k, [[0.26, 0.44]]) },
      bit1: { hide: off(k, [[0.44, 0.62]]) }, bit2: { hide: off(k, [[0.62, 0.8]]) }
    })
  } },
  // The waves go out from the dot.
  wifi: { ms: 800, at: function(k) { return pose(drawIn(k, "wave", 3, 0.15, 0.6)) } },
  // The sound goes out from the speaker.
  "volume-2": { ms: 700, at: function(k) { return pose(drawIn(k, "wave", 2, 0.2, 0.55)) } },
  // The crystal grows from its heart.
  snowflake: { ms: 800, at: function(k) { return pose(drawIn(k, "arm", 3, 0.15, 0.6)) } },
  // Gusts blow through, one line after another.
  wind: { ms: 900, at: function(k) {
    return pose({
      gust0: { x: track(k, [[0, 0], [0.08, 1], [0.3, 0]]) },
      gust1: { x: track(k, [[0, 0], [0.22, 1], [0.44, 0]]) },
      gust2: { x: track(k, [[0, 0], [0.36, 1], [0.58, 0]]) }
    })
  } },
  // The arrow's head pulls back the way it points.
  undo: { ms: 600, at: function(k) { return pose({ head: { x: track(k, [[0, 0], [0.12, -1], [0.55, 0]]) } }) } },
  "arrow-left": { ms: 600, at: function(k) { return pose({ head: { x: track(k, [[0, 0], [0.12, -1], [0.55, 0]]) } }) } },
  // The arrow runs round its circle.
  reload: { ms: 800, at: function(k) { return pose(drawIn(k, "arc", 6, 0.1, 0.7)) } },
  // The tick draws itself, short stroke first.
  check: { ms: 600, at: function(k) { return pose(drawIn(k, "stroke", 4, 0.12, 0.6)) } },
  // One stroke, then the other.
  close: { ms: 600, at: function(k) {
    return pose({ one: { hide: k < 0.15 }, two: { hide: k < 0.45 } })
  } },
  // The arrow drops into the tray and bounces.
  download: { ms: 800, at: function(k) {
    var y = track(k, [[0, -3], [0.1, -2], [0.2, -1], [0.3, 0], [0.42, 1], [0.58, 0]])
    return pose({ arrow: { y: y, hide: k < 0.1 } })
  } },
  // The warning flashes.
  "warning-diamond": { ms: 700, at: function(k) { return pose({ bang: { hide: off(k, [[0.1, 0.26], [0.42, 0.58]]) } }) } },
  // The dot over the i hops.
  "circle-info": { ms: 600, at: function(k) { return pose({ dot: { y: track(k, [[0, 0], [0.12, -1], [0.5, 0]]) } }) } },
  // The small sparkle twinkles.
  sparkles: { ms: 800, at: function(k) { return pose({ small: { hide: off(k, [[0.1, 0.28], [0.46, 0.64]]) } }) } },
  // The pane's divider slides over and back.
  layout: { ms: 700, at: function(k) { return pose({ divider: { x: track(k, [[0, 0], [0.15, 1], [0.35, 2], [0.6, 1], [0.8, 0]]) } }) } },
  // The swatches fan out, front to back.
  "colors-swatch": { ms: 700, at: function(k) { return pose(drawIn(k, "card", 3, 0.15, 0.6)) } },
  // Each knob slides along its track and back, one after another.
  "sliders-horizontal": { ms: 1000, at: function(k) {
    return pose({
      knobA: { f: track(k, [[0, 2], [0.06, 1], [0.16, 0], [0.32, 1], [0.42, 2]]) },
      knobB: { f: track(k, [[0, 0], [0.22, 1], [0.32, 2], [0.5, 1], [0.6, 0]]) },
      knobC: { f: track(k, [[0, 1], [0.4, 2], [0.56, 1], [0.66, 0], [0.82, 1]]) }
    })
  } },
  // The chevrons nudge the way they point.
  "chevron-down": { ms: 500, at: function(k) { return pose(null, { y: track(k, [[0, 0], [0.15, 1], [0.55, 0]]) }) } },
  "chevron-left": { ms: 500, at: function(k) { return pose(null, { x: track(k, [[0, 0], [0.15, -1], [0.55, 0]]) }) } },
  "chevron-right": { ms: 500, at: function(k) { return pose(null, { x: track(k, [[0, 0], [0.15, 1], [0.55, 0]]) }) } },
  // The cog turns one notch, an eighth and then a quarter, which looks just
  // as it began. The eighth is the one turn off the quarter turns pixel art
  // takes (the gear button's own turn is the other).
  "settings-cog": { ms: 600, at: function(k) { return pose(null, { turn: track(k, [[0, 0], [0.2, 45], [0.6, 90]]) }) } }
}

function hasStory(name) {
  return !!STORIES[name]
}

function duration(name) {
  return STORIES[name] ? STORIES[name].ms : 0
}

// The icon's pose `k` of the way through its story; at rest outside it.
function poseAt(name, k) {
  var story = STORIES[name]
  if (!story || !(k > 0 && k < 1)) return REST
  return story.at(k)
}

// A loop's pose at `t` ms into the shared clock (0..LOOP_MS). "turn" turns
// the whole icon a quarter every `every` ms; "spin" flips
// the fan's blades every `every` ms; "burst" plays the icon's story at the
// start of every `every` ms and rests for the rest of it.
function loopAt(name, kind, every, t) {
  if (!(every > 0)) return REST
  if (kind === "spin") return pose({ blades: { f: Math.floor(t / every) % 2 } })
  // A busy icon turning a quarter at a time, the one turn pixel art takes
  // whole.
  if (kind === "turn") return pose(null, { turn: 90 * (Math.floor(t / every) % 4) })
  if (kind === "burst") {
    var story = STORIES[name]
    if (!story) return REST
    return poseAt(name, (t % every) / story.ms)
  }
  return REST
}

// How long until the pose next changes, in ms, so the player can wake
// exactly then instead of sampling: at a fixed 33 ms a 150 ms flip held
// for 132 to 165. A story's steps are found by looking ahead in PROBE_MS
// steps; a spin flips on its boundary; a burst between plays waits for the
// next one.
var PROBE_MS = 4

function storyNext(name, k, ms) {
  var story = STORIES[name]
  if (!story || !(ms > 0)) return 0
  var now = JSON.stringify(poseAt(name, k))
  var left = (1 - k) * ms
  for (var dt = PROBE_MS; dt < left; dt += PROBE_MS)
    if (JSON.stringify(poseAt(name, k + dt / ms)) !== now) return dt
  return Math.max(1, Math.ceil(left))
}

function loopNext(name, kind, every, t) {
  if (!(every > 0)) return 0
  var toBoundary = every - (t % every)
  if (kind === "burst") {
    var story = STORIES[name]
    var into = t % every
    if (story && into < story.ms) return Math.min(toBoundary, storyNext(name, into / story.ms, story.ms))
  }
  return toBoundary
}

// How often the fan flips its blades while the panel is open and the fans
// run, in ms: faster for faster fans, never quicker than the eye can follow,
// and never while they stand still (0). Picked from flips whose pair (one
// turn of the art) divides the shared clock.
var SPIN_STEPS = [120, 150, 160, 200, 240, 300, 400, 480, 600]

function spinInterval(rpm) {
  if (!(rpm > 0)) return 0
  var want = Math.max(140, Math.min(520, 900 - rpm / 10))
  var best = SPIN_STEPS[0]
  for (var i = 0; i < SPIN_STEPS.length; i++)
    if (Math.abs(SPIN_STEPS[i] - want) < Math.abs(best - want)) best = SPIN_STEPS[i]
  return best
}
