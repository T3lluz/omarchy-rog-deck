.pragma library

// Pure parsing and formatting for the JSON from bin/rog-deck status.
// Nothing here touches QML, so tests/model.test.js can run it under node.

// power-profiles-daemon names, in tile order, with the names ROG uses. The
// glyphs are the ones Omarchy's own power menu shows for each profile, so
// the bar, the panel and the system agree.
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

// GPU modes, in tile order. bin/rog-deck lists the ones this laptop has.
var GPU_MODES = [
  { value: "integrated", label: "Integrated", icon: "󰌪", hint: "AMD only, NVIDIA powered off. Longest battery" },
  { value: "hybrid", label: "Hybrid", icon: "󰢮", hint: "AMD drives the screen, NVIDIA wakes for games" },
  { value: "dedicated", label: "Dedicated", icon: "󰓅", hint: "NVIDIA drives the screen directly (MUX). Lowest latency, most power" }
]

function gpuModes(gpu) {
  var available = gpu && gpu.modes ? gpu.modes : []
  return GPU_MODES.filter(function(m) { return available.indexOf(m.value) !== -1 })
}

function gpuModeInfo(value) {
  for (var i = 0; i < GPU_MODES.length; i++)
    if (GPU_MODES[i].value === value) return GPU_MODES[i]
  return { value: value || "", label: value ? value.charAt(0).toUpperCase() + value.slice(1) : "Unknown", icon: "󰢮", hint: "" }
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
    fnlock: null,
    refresh: null,
    // Battery saver: on battery, 60 Hz, panel overdrive off, panel power
    // saving and Wi-Fi power save. overdriveAc is the overdrive choice made
    // on the charger, put back when it returns.
    saver: { enabled: false, screen: true, wifi: true, overdriveAc: null },
    // Silent's CPU limit in watts, applied only while Silent is active.
    powerLimit: { enabled: false, watts: 15 },
    updates: { autoCheck: true }
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

var ANIME_SLOTS = [
  { slot: "boot", label: "Startup", icon: "󱓞" },
  { slot: "sleep", label: "Sleep", icon: "󰒲" },
  { slot: "shutdown", label: "Shutdown", icon: "󰐥" }
]

var ANIME_CONTENT = [
  { value: "banner", label: "Banner", icon: "󰊄", hint: "Scrolling ROG banner", builtin: "BinaryBannerScroll" },
  { value: "logo", label: "ROG Logo", icon: "󰈈", hint: "The glitching ROG eye", builtin: "RogLogoGlitch" }
]

// All four built-in slots, with one changed: asusd sets them together.
function animeBuiltins(anime, slot, name) {
  var current = anime && anime.builtins ? anime.builtins : {}
  var result = {}
  for (var key in ANIME_DEFAULT_BUILTINS) result[key] = current[key] || ANIME_DEFAULT_BUILTINS[key]
  if (slot) result[slot] = name
  return result
}

// What the panel shows while awake: the firmware's awake animation.
function animeContent(anime) {
  return anime && anime.builtins && anime.builtins.awake === "RogLogoGlitch" ? "logo" : "banner"
}

// -------------------------------------------------------------- display

// Hz to switch to for a refresh setting, or 0 to leave it: "auto" follows
// the charger. Battery saver holds 60 Hz on battery whatever the setting,
// and puts the top rate back on the charger unless a fixed rate was picked.
function refreshTarget(mode, display, onAc, saver) {
  if (!display || !display.rates || display.rates.length === 0) return 0
  var rates = display.rates
  var low = rates.indexOf(60) !== -1 ? 60 : rates[0]
  if (saver && !onAc) return low
  if (saver && !mode) mode = "auto"
  if (!mode) return 0
  if (mode === "auto") return onAc ? rates[rates.length - 1] : low
  var hz = parseInt(mode, 10)
  return rates.indexOf(hz) !== -1 ? hz : 0
}

// ------------------------------------------------------ battery saver

// What Battery saver does to panel overdrive when it starts (active) or
// stops holding the battery settings: { set: 0|1|null, remember: 0|1 }.
// Starting turns an "on" off and remembers it; stopping puts it back.
function saverOverdrive(active, current, remembered) {
  if (current !== 0 && current !== 1) return { set: null }
  if (active) return current === 1 ? { set: 0, remember: 1 } : { set: null }
  return remembered === 1 && current === 0 ? { set: 1 } : { set: null }
}

// The panel power savings level Battery saver holds: amdgpu's 0 (off) to 4.
// 3 is the strongest power-profiles-daemon itself uses in power-saver.
var SCREEN_SAVING_LEVEL = 3

function screenLevel(active, saver) {
  return active && saver && saver.screen ? SCREEN_SAVING_LEVEL : 0
}

// Sustained at `watts`; the boosts follow it but never drop below their
// firmware minimum. bin/rog-deck's ppt_triple does the same when applying.
function pptTriple(watts, ranges) {
  if (!ranges || !ranges.spl || !ranges.sppt || !ranges.fppt) return null
  function clamp(value, bounds) { return Math.max(bounds[0], Math.min(bounds[1], value)) }
  var w = Math.round(Number(watts) || 0)
  var spl = clamp(w, ranges.spl)
  var sppt = clamp(Math.max(w, spl), ranges.sppt)
  return { spl: spl, sppt: sppt, fppt: clamp(Math.max(w, sppt), ranges.fppt) }
}

// The watts to hold the CPU to in this mode, or 0 for the firmware's own
// limits. Only Silent gets a limit.
function powerLimitWatts(settings, profile, power) {
  var limit = settings && settings.powerLimit
  if (!limit || !limit.enabled || profile !== "power-saver") return 0
  if (!power || !power.supported || !power.slider) return 0
  var w = Math.round(Number(limit.watts) || 0)
  return Math.max(power.slider[0], Math.min(power.slider[1], w))
}

function limitCaption(triple) {
  if (!triple) return ""
  if (triple.spl === triple.sppt && triple.sppt === triple.fppt) return triple.spl + " W, boosts included"
  var boost = triple.sppt === triple.fppt ? triple.sppt + " W" : triple.sppt + " / " + triple.fppt + " W"
  return triple.spl + " W sustained · boosts to " + boost
}

// Whether the helper's last write is this triple on this power source.
function limitApplied(applied, triple, onAc) {
  return !!applied && !!triple && applied.spl === triple.spl && applied.sppt === triple.sppt
    && applied.fppt === triple.fppt && applied.ac === onAc
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

// ------------------------------------------------------------------ bar

// What the bar can show next to the mode icon, in bar order. `key` is the
// shell.json setting; barTemps and barFans keep their 0.3 names.
var BAR_STATS = [
  { key: "barModeName", stat: "mode", label: "Mode name", icon: "󰊚", fallback: false },
  { key: "barTemps", stat: "cpuTemp", label: "CPU temp", icon: "󰔏", fallback: false },
  { key: "barGpuTemp", stat: "gpuTemp", label: "GPU temp", icon: "󰢮", hint: "Only while the NVIDIA GPU is awake", fallback: false },
  { key: "barFans", stat: "fans", label: "Fan speed", icon: "󰈐", hint: "The faster of the CPU and GPU fans", fallback: false },
  { key: "barPower", stat: "power", label: "Package power", icon: "󰻠", hint: "CPU and iGPU draw", fallback: false },
  { key: "barDgpu", stat: "dgpu", label: "NVIDIA state", icon: "󰾲", hint: "Awake, asleep or off, with its draw while awake", fallback: false },
  { key: "barBattery", stat: "battery", label: "Battery", icon: "󰁹", fallback: false },
  { key: "barRefresh", stat: "refresh", label: "Refresh rate", icon: "󰍹", fallback: false }
]

// One entry per picked stat that has a reading: { stat, text, temp }.
// `temp` is set for temperatures so the bar can colour them by heat.
function barParts(status, picked) {
  if (!status || !status.asusd || !picked || picked.length === 0) return []
  var parts = []
  var t = status.temps || {}
  for (var i = 0; i < picked.length; i++) {
    var stat = picked[i]
    if (stat === "mode") {
      parts.push({ stat: stat, text: profileInfo(status.profile && status.profile.active).label, temp: null })
    } else if (stat === "cpuTemp") {
      parts.push({ stat: stat, text: "󰔏 " + temperature(t.cpu), temp: t.cpu === undefined ? null : t.cpu })
    } else if (stat === "gpuTemp") {
      // No reading while the dGPU sleeps; it is not woken to get one.
      if (t.gpu !== null && t.gpu !== undefined) parts.push({ stat: stat, text: "󰢮 " + temperature(t.gpu), temp: t.gpu })
    } else if (stat === "fans") {
      var fan = maxFan(status)
      if (fan !== null) parts.push({ stat: stat, text: "󰈐 " + rpm(fan), temp: null })
    } else if (stat === "power") {
      var w = status.watts ? status.watts.igpu : null
      if (w !== null && w !== undefined) parts.push({ stat: stat, text: "󰻠 " + watts(w), temp: null })
    } else if (stat === "dgpu") {
      if (status.dgpu) {
        var dw = status.watts ? status.watts.dgpu : null
        parts.push({ stat: stat, text: "󰢮 " + (status.dgpu === "active" && dw ? watts(dw) : dgpuLabel(status.dgpu)), temp: null })
      }
    } else if (stat === "battery") {
      var b = status.battery
      if (b && b.percent !== null && b.percent !== undefined)
        parts.push({ stat: stat, text: (status.ac ? "󰂄 " : "󰁹 ") + b.percent + "%", temp: null })
    } else if (stat === "refresh") {
      if (status.display && status.display.refresh) parts.push({ stat: stat, text: "󰍹 " + status.display.refresh + " Hz", temp: null })
    }
  }
  return parts
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

// -------------------------------------------------------------- notices

// The confirm prompt for a GPU switch.
function gpuConfirmText(gpu, mode) {
  var text = "Switch to " + gpuModeInfo(mode).label + " GPU mode? "
  if (mode === "integrated" && gpu && gpu.needsSetup)
    text += "ROG Deck first installs supergfxctl, which asks for your password. "
  return text + "The laptop then restarts, closing open windows."
}

// The banner over every tab while a GPU switch waits for a restart, or null.
function gpuNotice(gpu, next) {
  if (!gpu || !next || next === gpu.mode) return null
  return { key: "gpu", tone: "accent", icon: "󰜉", text: "Restart to finish switching to " + gpuModeInfo(next).label + " GPU mode",
           action: "restart", actionLabel: "Restart" }
}

// With Battery saver on, a banner while on battery with the NVIDIA GPU in
// use, pointing at Integrated, or null.
function batteryGpuNotice(gpu, next, onBattery, saver) {
  if (!saver || !onBattery || !gpu || !gpu.modes || gpu.modes.indexOf("integrated") === -1) return null
  if (gpu.mode === "integrated" || next === "integrated") return null
  return { key: "gpu-battery", tone: "accent", icon: "󰌪", dismissable: true,
           text: "On battery in " + gpuModeInfo(gpu.mode).label + " mode. Integrated keeps the NVIDIA GPU off and lasts longest",
           action: "integrated", actionLabel: "Integrated" }
}

// The banner asking to install or update the power helper, or null.
function powerHelperNotice(power, wanted) {
  if (!wanted || !power || !power.supported || power.helper === "ok") return null
  return { key: "power-helper", tone: "accent", icon: "󰌾", action: "power-setup", actionLabel: "Set up",
           text: power.helper === "outdated"
             ? "ROG Deck's power helper needs an update. It asks for your password once"
             : "The CPU limit and Wi-Fi power save need ROG Deck's power helper. It asks for your password once" }
}
