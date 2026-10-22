.pragma library

// Pure parsing and formatting for the JSON from bin/rog-deck status.
// Nothing here touches QML, so tests/model.test.js can run it under node.

// power-profiles-daemon names, in tile order, with the names ROG uses.
var PROFILES = [
  { key: "power-saver", label: "Silent", icon: "󰌪", hint: "Quiet fans, low power, longest battery" },
  { key: "balanced", label: "Balanced", icon: "󰊚", hint: "Everyday mode" },
  { key: "performance", label: "Turbo", icon: "󰓅", hint: "Full CPU and GPU power, louder fans" }
]

function parseStatus(raw) {
  try {
    var data = JSON.parse(String(raw || "").trim())
    return data && typeof data === "object" ? data : null
  } catch (e) {
    return null
  }
}

// Accept the ROG and asusd names as well as the daemon's.
function normalizeProfile(name) {
  var key = String(name || "").trim().toLowerCase()
  if (key === "silent" || key === "quiet" || key === "low-power" || key === "lowpower") return "power-saver"
  if (key === "turbo") return "performance"
  return key
}

function profileInfo(key) {
  for (var i = 0; i < PROFILES.length; i++)
    if (PROFILES[i].key === key) return PROFILES[i]
  return { key: key || "", label: key ? key.charAt(0).toUpperCase() + key.slice(1) : "Unknown", icon: "󰂄", hint: "" }
}

// The profiles to show as tiles: the daemon's list, in our order.
function profileChoices(status) {
  var choices = status && status.profile && status.profile.choices
  if (!choices || choices.length === 0) return []
  return PROFILES.filter(function(p) { return choices.indexOf(p.key) !== -1 })
}

// Next profile by wheel delta; stops at the ends instead of wrapping, so a
// long scroll can't spin past the mode you wanted.
function steppedProfile(status, delta) {
  var choices = profileChoices(status)
  if (choices.length === 0 || !delta) return ""
  var active = status.profile.active
  var index = -1
  for (var i = 0; i < choices.length; i++) if (choices[i].key === active) index = i
  if (index === -1) return choices[0].key
  var next = Math.max(0, Math.min(choices.length - 1, index + (delta > 0 ? 1 : -1)))
  return next === index ? "" : choices[next].key
}

// 0 cool, 1 warm, 2 hot.
function heat(celsius) {
  if (celsius === null || celsius === undefined) return 0
  if (celsius >= 85) return 2
  if (celsius >= 70) return 1
  return 0
}

function temperature(value) {
  return value === null || value === undefined ? "—" : Math.round(value) + "°"
}

function watts(value) {
  if (value === null || value === undefined) return ""
  return (value >= 10 ? Math.round(value) : Math.round(value * 10) / 10) + " W"
}

function rpm(value) {
  if (value === null || value === undefined) return "—"
  if (value === 0) return "off"
  return value >= 1000 ? (Math.round(value / 100) / 10) + "k" : String(value)
}

function maxFan(status) {
  var fans = status && status.fans
  if (!fans) return null
  var best = null
  for (var key in fans) if (fans[key] !== null && (best === null || fans[key] > best)) best = fans[key]
  return best
}

// What the dGPU is doing, in words. "suspended" means runtime-suspended
// (D3cold, about 0 W), which is the normal idle state in Hybrid mode.
function dgpuLabel(state) {
  if (state === "active") return "awake"
  if (state === "suspended") return "asleep"
  if (state === "absent") return "off"
  return state || "—"
}

function batteryLine(battery, onAc) {
  if (!battery || battery.percent === null || battery.percent === undefined) return ""
  var text = battery.percent + "%"
  if (battery.watts) text += (onAc ? " +" : " −") + watts(battery.watts)
  return text
}

// ------------------------------------------------------------- settings

function defaultSettings() {
  return {
    version: 1,
    kbdIdle: { enabled: true, timeout: 60, keepOnAc: false, dimOnly: false },
    // managed: the user picked an effect here, so re-apply it after Omarchy's
    // theme switcher resets the keyboard. rgb: the keyboard shows colours
    // (asusd lists RGB effects even on white-only keyboards).
    kbdLight: { managed: false, rgb: false, followTheme: true, effect: "static",
                colour: "ffffff", colour2: "000000", speed: "med", direction: "right" },
    kbdLastLevel: 2,
    anime: { content: "banner", customPath: "", placement: {
      static: animePlacementDefaults("static"), custom: animePlacementDefaults("custom") } },
    fnlock: null,
    refresh: null
  }
}

// Saved settings over the defaults, keeping only values of the right type.
function formatSeconds(seconds) {
  var s = Math.round(Number(seconds) || 0)
  if (s < 60) return s + " s"
  var m = Math.floor(s / 60), r = s % 60
  return r ? m + " min " + r + " s" : m + " min"
}

function mergeSettings(raw) {
  var base = defaultSettings()
  var saved
  try { saved = JSON.parse(String(raw || "{}")) } catch (e) { saved = {} }
  if (!saved || typeof saved !== "object") return base
  function overlay(target, source) {
    for (var key in target) {
      if (!source || !source.hasOwnProperty(key)) continue
      var want = target[key], got = source[key]
      if (want !== null && typeof want === "object") overlay(want, got)
      else if (want === null || typeof want === typeof got) target[key] = got
    }
  }
  overlay(base, saved)
  return base
}

function cleanHex(text) {
  var hex = String(text || "").trim().replace(/^#/, "").toLowerCase()
  return /^[0-9a-f]{6}$/.test(hex) ? hex : ""
}

// ------------------------------------------------------------- keyboard

var AURA_EFFECTS = [
  { key: "static", id: 0, label: "Static", colour: true, speed: false, rgbOnly: false },
  { key: "breathe", id: 1, label: "Breathe", colour: true, speed: true, rgbOnly: true },
  { key: "pulse", id: 10, label: "Pulse", colour: true, speed: false, rgbOnly: true },
  { key: "rainbow-cycle", id: 2, label: "Rainbow", colour: false, speed: true, rgbOnly: true },
  { key: "rainbow-wave", id: 3, label: "Wave", colour: false, speed: true, rgbOnly: true }
]

var KBD_LEVELS = [
  { value: 0, label: "Off" }, { value: 1, label: "Low" }, { value: 2, label: "Med" }, { value: 3, label: "High" }
]

var IDLE_TIMEOUTS = [
  { value: 15, label: "15 s" }, { value: 30, label: "30 s" }, { value: 60, label: "1 min" },
  { value: 120, label: "2 min" }, { value: 300, label: "5 min" }, { value: 600, label: "10 min" }
]

var SWATCHES = ["ffffff", "ff0033", "ff7a00", "ffd400", "00e676", "00b0ff", "2962ff", "d500f9"]

function auraEffect(key) {
  for (var i = 0; i < AURA_EFFECTS.length; i++) if (AURA_EFFECTS[i].key === key) return AURA_EFFECTS[i]
  return null
}

function auraEffectId(key) {
  var effect = auraEffect(key)
  return effect ? effect.id : -1
}

function auraEffectLabel(key) {
  var effect = auraEffect(key)
  return effect ? effect.label : key
}

function auraEffectByMode(id) {
  for (var i = 0; i < AURA_EFFECTS.length; i++) if (AURA_EFFECTS[i].id === id) return AURA_EFFECTS[i]
  return null
}

// The effects to offer: what asusd says the keyboard supports. A white-only
// keyboard gets Static alone: asusd lists every effect for it, but the
// animated ones only pulse a single white and can leave it stuck animating.
function auraEffects(supported, rgb) {
  var ids = supported || []
  return AURA_EFFECTS.filter(function(e) { return ids.indexOf(e.id) !== -1 && (rgb || !e.rgbOnly) })
}

function nextAuraEffect(current, supported, rgb) {
  var list = auraEffects(supported, rgb)
  if (list.length === 0) return ""
  var index = -1
  for (var i = 0; i < list.length; i++) if (list[i].key === current) index = i
  return list[(index + 1) % list.length].key
}

// Arguments for `rog-deck aura`, or null if the effect is unknown.
function auraArgs(light, themeColour) {
  var effect = auraEffect(light.effect)
  if (!effect) return null
  var colour = light.followTheme && cleanHex(themeColour) ? cleanHex(themeColour) : (cleanHex(light.colour) || "ffffff")
  if (!light.rgb) colour = "ffffff"
  var args = [effect.key]
  if (effect.colour) args.push("--colour", colour)
  if (effect.key === "breathe") args.push("--colour2", cleanHex(light.colour2) || "000000")
  if (effect.speed) args.push("--speed", light.speed || "med")
  if (effect.key === "rainbow-wave") args.push("--direction", light.direction || "right")
  return args
}

// ---------------------------------------------------------------- anime

var ANIME_DEFAULT_BUILTINS = { boot: "GlitchConstruction", awake: "BinaryBannerScroll", sleep: "Starfield", shutdown: "SeeYa" }

var ANIME_BUILTIN_CHOICES = {
  boot: [{ value: "GlitchConstruction", label: "Glitch" }, { value: "StaticEmergence", label: "Emerge" }],
  sleep: [{ value: "Starfield", label: "Starfield" }, { value: "BannerSwipe", label: "Swipe" }],
  shutdown: [{ value: "SeeYa", label: "See ya" }, { value: "GlitchOut", label: "Glitch out" }]
}

var ANIME_CONTENT = [
  { value: "banner", label: "Banner", hint: "Scrolling ROG banner (firmware)" },
  { value: "logo", label: "Logo", hint: "Glitching ROG eye (firmware)" },
  { value: "static", label: "Static", hint: "The ROG eye, still" },
  { value: "custom", label: "Image", hint: "Your own PNG or GIF" }
]

// Where an image sits on the panel, in asusctl's terms: scale 1 fits the
// panel, x/y in its physical units (about 27 wide, 17 tall), angle in
// degrees, bright in percent. The logo default matches RogLogoGlitch.
function animePlacementDefaults(content) {
  return content === "static"
    ? { scale: 1.25, x: 0, y: -0.8, angle: 0, bright: 100 }
    : { scale: 1, x: 0, y: 0, angle: 0, bright: 100 }
}

function animePlacementArgs(placement) {
  var p = placement || animePlacementDefaults("custom")
  function fixed(v, digits) { return String(Math.round(Number(v) * Math.pow(10, digits)) / Math.pow(10, digits)) }
  return ["--scale", fixed(p.scale, 2), "--x", fixed(p.x, 2), "--y", fixed(p.y, 2),
          "--angle", fixed(p.angle, 0), "--bright", fixed(p.bright, 0)]
}

// All four built-in slots, with one changed: asusd sets them together.
function animeBuiltins(anime, slot, name) {
  var current = anime && anime.builtins ? anime.builtins : {}
  var result = {}
  for (var key in ANIME_DEFAULT_BUILTINS) result[key] = current[key] || ANIME_DEFAULT_BUILTINS[key]
  if (slot) result[slot] = name
  return result
}

// What the panel is showing: built-ins win when they are running.
function animeContent(saved, anime) {
  if (anime && anime.builtinsEnabled)
    return anime.builtins && anime.builtins.awake === "RogLogoGlitch" ? "logo" : "banner"
  return saved === "custom" ? "custom" : "static"
}

// -------------------------------------------------------------- display

// Hz to switch to for a refresh setting: "auto" follows the charger.
function refreshTarget(mode, display, onAc) {
  if (!mode || !display || !display.rates || display.rates.length === 0) return 0
  var rates = display.rates
  if (mode === "auto") {
    if (onAc) return rates[rates.length - 1]
    return rates.indexOf(60) !== -1 ? 60 : rates[0]
  }
  var hz = parseInt(mode, 10)
  return rates.indexOf(hz) !== -1 ? hz : 0
}

// ----------------------------------------------------------------- fans

var FAN_PRESETS = [
  { value: "silent", label: "Silent", hint: "Fans off until about 70 °C" },
  { value: "stock", label: "Stock", hint: "Close to the firmware curve" },
  { value: "cool", label: "Cool", hint: "Spins up early" },
  { value: "max", label: "Max", hint: "Full speed" }
]

function curveString(points) {
  return (points || []).map(function(p) { return Math.round(p.t) + ":" + Math.round(p.p) }).join(",")
}

// Keep a dragged point inside its neighbours' temperatures and 0..100 %.
function clampPoint(points, index, t, p) {
  var lo = index > 0 ? points[index - 1].t : 20
  var hi = index < points.length - 1 ? points[index + 1].t : 110
  return { t: Math.max(lo, Math.min(hi, Math.round(t))), p: Math.max(0, Math.min(100, Math.round(p))) }
}

function tooltip(status) {
  if (!status) return "ROG Deck: reading the laptop…"
  if (!status.asusd) return "ROG Deck: asusd is not running"
  var lines = []
  lines.push(profileInfo(status.profile && status.profile.active).label + " mode")
  var t = status.temps || {}
  var parts = ["CPU " + temperature(t.cpu)]
  if (t.gpu !== null && t.gpu !== undefined) parts.push("GPU " + temperature(t.gpu))
  lines.push(parts.join("  "))
  var fans = status.fans || {}
  if (fans.cpu !== null || fans.gpu !== null)
    lines.push("Fans " + rpm(fans.cpu) + " / " + rpm(fans.gpu) + " rpm")
  var battery = batteryLine(status.battery, status.ac)
  if (battery) lines.push("Battery " + battery)
  return lines.join("\n")
}
