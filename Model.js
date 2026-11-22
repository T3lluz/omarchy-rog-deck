.pragma library

// Pure parsing and formatting for the JSON from bin/rog-deck status.
// Nothing here touches QML, so tests/model.test.js can run it under node.

// power-profiles-daemon names, in tile order, with the names ROG uses. The
// glyphs are the ones Omarchy's own power menu shows for each profile, so
// the bar, the panel and the system agree.
// `pixel` is the mode's pixel icon in the bar and the panel, after the same
// glyphs: a leaf, then a dial whose needle swings from upright to fast.
var PROFILES = [
  { key: "power-saver", label: "Silent", icon: "󰌪", pixel: "leaf", hint: "Quiet fans, low power, longest battery" },
  { key: "balanced", label: "Balanced", icon: "󰊚", pixel: "speed-medium", hint: "Everyday mode" },
  { key: "performance", label: "Turbo", icon: "󰓅", pixel: "speed-fast", hint: "Full CPU and GPU power, louder fans" }
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
  return { key: key || "", label: key ? key.charAt(0).toUpperCase() + key.slice(1) : "Unknown", icon: "󰊚", pixel: "speed-medium", hint: "" }
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
  return value >= 1000 ? (Math.round(value / 100) / 10).toFixed(1) + "k" : String(value)
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
  { value: "integrated", label: "Integrated", icon: "󰌪", pixel: "leaf", hint: "AMD only, NVIDIA powered off. Longest battery" },
  { value: "hybrid", label: "Hybrid", icon: "󰢮", pixel: "gpu", hint: "AMD drives the screen, NVIDIA wakes for games" },
  { value: "dedicated", label: "Dedicated", icon: "󰓅", pixel: "speed-fast", hint: "NVIDIA drives the screen directly (MUX). Lowest latency, most power" }
]

function gpuModes(gpu) {
  var available = gpu && gpu.modes ? gpu.modes : []
  return GPU_MODES.filter(function(m) { return available.indexOf(m.value) !== -1 })
}

function gpuModeInfo(value) {
  for (var i = 0; i < GPU_MODES.length; i++)
    if (GPU_MODES[i].value === value) return GPU_MODES[i]
  return { value: value || "", label: value ? value.charAt(0).toUpperCase() + value.slice(1) : "Unknown", icon: "󰢮", pixel: "gpu", hint: "" }
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
    // Full speed on the charger in Balanced: the CPU's performance energy
    // preference. Needs the helper, so it is on by default but does nothing
    // until that is set up.
    fullSpeed: { enabled: true },
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
  { value: "banner", label: "Banner", icon: "󰊄", pixel: "binary", hint: "Scrolling ROG banner", builtin: "BinaryBannerScroll" },
  { value: "logo", label: "ROG logo", icon: "󰈈", pixel: "eye", hint: "The glitching ROG eye", builtin: "RogLogoGlitch" }
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

// Full speed holds on the charger in Balanced. Turbo's performance governor
// already holds the CPU there, and Silent and the battery keep the energy
// preference power-profiles-daemon picks.
function speedWanted(settings, profile, onAc) {
  var speed = settings && settings.fullSpeed
  return !!speed && speed.enabled === true && !!onAc && profile === "balanced"
}

// What to run for the current mode and charger: "on" to put full speed in
// place, "off" to hand back what an earlier "on" set, "" for nothing.
// speed is the status's: the CPU's energy preference (null where the driver
// has none, "mixed" after a write that stopped partway) and whether ROG Deck
// holds it. A performance preference nobody holds also gets "on":
// power-profiles-daemon never picks it for Balanced, so it is treated as ROG
// Deck's from before a logout, and claiming it is what lets a later "off"
// hand it back.
function speedPlan(settings, profile, onAc, speed) {
  if (!speed || !speed.epp) return ""
  if (speedWanted(settings, profile, onAc)) return speed.epp !== "performance" || !speed.held ? "on" : ""
  return speed.held ? "off" : ""
}

// The switch's caption. helper: "ok", "missing" or "outdated". Without a
// working helper the switch shows off whatever is saved, and a click sets
// the helper up. epp: the CPU's energy preference now, so "On now" is only
// said when it is.
function speedHint(enabled, helper, onAc, epp) {
  var does = "On the charger, the CPU clocks up at once, as in Turbo, instead of ramping"
  if (helper !== "ok") {
    if (!enabled) return does + ". Asks for your password once"
    return helper === "outdated" ? "Off until ROG Deck's power helper is updated. Click to update it. Asks for your password once"
                                 : "Off until ROG Deck's power helper is set up. Click to set it up. Asks for your password once"
  }
  if (!enabled) return does
  if (!onAc) return "Waiting for the charger. On battery the mode's own setting applies"
  return epp === "performance" ? "On now. The CPU clocks up at once instead of ramping" : does
}

// ----------------------------------------------------------------- fans

var FAN_PRESETS = [
  { value: "silent", label: "Silent", pixel: "leaf", hint: "Fans off until about 70 °C" },
  { value: "stock", label: "Stock", pixel: "fan", hint: "Close to the firmware curve" },
  { value: "cool", label: "Cool", pixel: "snowflake", hint: "Spins up early" },
  { value: "max", label: "Max", pixel: "wind", hint: "Full speed" }
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

// Figures as the pixel type writes them (components/Rooms.js PIXEL_FONT):
// no spaces before a unit, so a bar item stays narrow.
function pixelWatts(value) {
  if (value === null || value === undefined) return ""
  return (value >= 10 ? Math.round(value) : Math.round(value * 10) / 10) + "W"
}

function pixelTemp(value) {
  return value === null || value === undefined ? "--" : Math.round(value) + "°"
}

// The battery's pixel icon by its level.
function batteryPixel(percent) {
  if (percent === null || percent === undefined) return "battery"
  if (percent <= 15) return "battery-low"
  if (percent < 60) return "battery-medium"
  return "battery-full"
}

// One entry per picked stat that has a reading, in the bar's pixel icons and
// pixel type: { stat, icon, text, word, hot }. `word` is set where the entry
// is a word rather than a figure (the mode's name), which the bar writes in
// its own font. `hot` marks a temperature at 85 °C or more, which the bar
// shows in its urgent colour: the bar keeps its own colours otherwise.
function barParts(status, picked) {
  if (!status || !status.asusd || !picked || picked.length === 0) return []
  var parts = []
  var t = status.temps || {}
  function add(stat, icon, text, hot) { parts.push({ stat: stat, icon: icon, text: text, word: "", hot: !!hot }) }
  for (var i = 0; i < picked.length; i++) {
    var stat = picked[i]
    if (stat === "mode") {
      var info = profileInfo(status.profile && status.profile.active)
      parts.push({ stat: stat, icon: "", text: "", word: info.label, hot: false })
    } else if (stat === "cpuTemp") {
      add(stat, "thermometer", pixelTemp(t.cpu), heat(t.cpu) === 2)
    } else if (stat === "gpuTemp") {
      // No reading while the dGPU sleeps; it is not woken to get one.
      if (t.gpu !== null && t.gpu !== undefined) add(stat, "gpu", pixelTemp(t.gpu), heat(t.gpu) === 2)
    } else if (stat === "fans") {
      var fan = maxFan(status)
      if (fan !== null) add(stat, "fan", rpm(fan))
    } else if (stat === "power") {
      var w = status.watts ? status.watts.igpu : null
      if (w !== null && w !== undefined) add(stat, "cpu", pixelWatts(w))
    } else if (stat === "dgpu") {
      if (status.dgpu) {
        var dw = status.watts ? status.watts.dgpu : null
        var said = status.dgpu === "active" ? (dw ? pixelWatts(dw) : "") : status.dgpu === "suspended" ? "Zz" : status.dgpu === "absent" ? "off" : ""
        add(stat, "gpu", said)
      }
    } else if (stat === "battery") {
      var b = status.battery
      if (b && b.percent !== null && b.percent !== undefined) add(stat, batteryPixel(b.percent), b.percent + "%")
    } else if (stat === "refresh") {
      if (status.display && status.display.refresh) add(stat, "monitor", status.display.refresh + "Hz")
    }
  }
  return parts
}

// --------------------------------------------------------------- rooms

// Each room's tone, by what it is, the way the plugins agree on them: power
// and the machine blue, health green, cooling and input cyan, light yellow,
// play green, a display of its own magenta. Neighbours never share one; the
// rows are Power, then the CPU and GPU with the Fans and Battery tiles
// stacked beside them, Graphics and Display, Keyboard and AniMe. The fans
// take magenta because cyan is beside them and blue above.
var ROOM_TONES = {
  power: "blue",
  heat: "cyan",
  fans: "magenta",
  battery: "green",
  display: "yellow",
  graphics: "green",
  keyboard: "cyan",
  anime: "magenta",
  mark: "yellow"
}

function roomTone(room) {
  return ROOM_TONES[room] || ""
}

// What the power room says under the mode's name. ctx: { ac, saverActive,
// profile, speed ({ epp, held }), speedOn (full speed saved and its helper
// working), limit ({ enabled, watts }), limitShown }.
function powerState(ctx) {
  if (!ctx) return ""
  var parts = [ctx.ac ? "Plugged in" : "On battery"]
  if (ctx.profile === "balanced" && ctx.speedOn && ctx.ac) parts.push(ctx.speed && ctx.speed.epp === "performance" ? "full speed" : "full speed soon")
  if (ctx.profile === "power-saver" && ctx.limitShown && ctx.limit && ctx.limit.enabled) parts.push("held to " + ctx.limit.watts + " W")
  if (ctx.saverActive) parts.push("Battery saver")
  return parts.join(" · ")
}

// The mark beside the package power: a bolt while full speed holds.
function powerMark(ctx) {
  return ctx && ctx.ac && ctx.profile === "balanced" && ctx.speed && ctx.speed.held && ctx.speed.epp === "performance" ? "zap" : ""
}

// The battery room: { level, state, mark, limit }. The mark is a bolt while
// it charges, a plug while on the charger and holding, the low battery when
// it runs low; low never rests on colour alone. The state is short: the
// tile's tooltip says it, and the power flowing is in the room's drawer.
function batteryRoom(battery, ac, saverActive) {
  if (!battery || battery.percent === null || battery.percent === undefined)
    return { level: null, state: ac ? "Plugged in" : "No reading", mark: "", limit: -1 }
  var pct = battery.percent
  var limit = battery.limit && battery.limit < 100 ? battery.limit : -1
  var charging = /^charging$/i.test(String(battery.status || ""))
  var state, mark = ""
  if (charging) {
    state = "Charging"
    mark = "zap"
  } else if (ac) {
    state = limit > 0 && pct >= limit - 1 ? "Held at " + limit + "%" : pct >= 99 ? "Full" : "Plugged in"
    mark = "plug"
  } else {
    state = saverActive ? "Saver on" : "On battery"
    if (pct <= 15) mark = "battery-low"
  }
  return { level: pct, state: state, mark: mark, limit: limit }
}

// The battery room's readings: the power flowing in or out, and what the
// kernel says it is doing. The limit is the fader under them.
function batteryFacts(battery, ac) {
  if (!battery || battery.percent === null || battery.percent === undefined) return []
  var w = battery.watts
  var flow = !w ? "0 W" : (ac ? "+" : "−") + watts(w)
  var list = [{ label: "Power", value: flow }]
  if (battery.status) list.push({ label: "State", value: String(battery.status) })
  return list
}

// The fans room's two parts, CPU and GPU: the temperature over a meter of it
// (0 to 100 °C) and what the part's fan does. The GPU reads nothing while it
// sleeps; it is not woken to read it.
function fanParts(status) {
  var t = status && status.temps ? status.temps : {}
  var f = status && status.fans ? status.fans : {}
  var parts = []
  function fanLine(value) { return value === null || value === undefined ? "no fan reading" : value === 0 ? "fan off" : rpm(value) + " rpm" }
  // How warm, in a word, for the line under the part's name.
  function warmth(temp, asleep) {
    if (temp === null || temp === undefined) return asleep ? "Asleep" : "No reading"
    return ["Cool", "Warm", "Hot"][heat(temp)]
  }
  if (t.cpu !== undefined || f.cpu !== undefined)
    parts.push({ key: "cpu", label: "CPU", icon: "cpu", temp: t.cpu === undefined ? null : t.cpu, rpm: f.cpu === undefined ? null : f.cpu,
                 state: fanLine(f.cpu), warmth: warmth(t.cpu, false), hot: heat(t.cpu) === 2 })
  if (t.gpu !== undefined || f.gpu !== undefined) {
    var asleep = (t.gpu === null || t.gpu === undefined) && status && status.dgpu !== "active"
    parts.push({ key: "gpu", label: "GPU", icon: "gpu", temp: t.gpu === undefined ? null : t.gpu, rpm: f.gpu === undefined ? null : f.gpu,
                 state: (asleep ? "asleep · " : "") + fanLine(f.gpu), warmth: warmth(t.gpu, asleep), hot: heat(t.gpu) === 2 })
  }
  return parts
}

function fansState(custom, known) {
  if (!known) return "Reading the curves"
  return custom ? "Custom curve" : "Firmware curve"
}

// How hot the CPU and GPU run, by the hotter of the two: the same steps the
// bar's colour and the hot mark use.
function heatState(temps) {
  var t = temps || {}
  var hottest = null
  if (t.cpu !== null && t.cpu !== undefined) hottest = t.cpu
  if (t.gpu !== null && t.gpu !== undefined && (hottest === null || t.gpu > hottest)) hottest = t.gpu
  if (hottest === null) return "No reading"
  return ["Cool", "Warm", "Hot"][heat(hottest)]
}

// The fans room's line: how fast the faster fan spins, and a custom curve
// when one runs (the firmware's is the usual, so it goes unsaid).
function fansLine(fastest, custom, known) {
  var speed = fastest === null || fastest === undefined ? "No fan reading" : fastest === 0 ? "Stopped" : rpm(fastest) + " rpm"
  return known && custom ? speed + " · custom curve" : speed
}

// The fans room's figure: the faster fan in thousands, one decimal, as the
// rest of the panel writes it (4.3k), or the plain number under 1000.
function fanFigure(value) {
  if (value === null || value === undefined) return { text: "", suffix: "" }
  if (value < 1000) return { text: String(Math.round(value)), suffix: "" }
  return { text: (Math.round(value / 100) / 10).toFixed(1), suffix: "k" }
}

// The fans room opened: both temperatures and both fans.
function fanFacts(status) {
  return fanParts(status).map(function(p) {
    var temp = p.temp === null || p.temp === undefined ? "asleep" : Math.round(p.temp) + " °C"
    var fan = p.rpm === null || p.rpm === undefined ? "" : p.rpm === 0 ? ", fan off" : ", " + rpm(p.rpm) + " rpm"
    return { label: p.label, value: temp + fan }
  })
}

// What the graphics room says: the NVIDIA GPU's state, or the mode waiting
// on a restart.
function graphicsState(gpu, dgpu, dgpuWatts, next) {
  if (gpu && next && next !== gpu.mode) return gpuModeInfo(next).label + " after a restart"
  // Its draw is the room's figure, so the line leaves it out.
  if (dgpu === "active") return "NVIDIA awake"
  if (dgpu === "suspended") return "NVIDIA asleep"
  if (dgpu === "absent") return "NVIDIA off"
  return ""
}

// The display room's line: how the rate is chosen. Short: the rate itself
// is the room's figure, and the drawer says the rest.
function displayState(refresh, saverActive, ac) {
  if (saverActive) return "Battery saver"
  if (refresh === "auto") return "Auto rate"
  if (refresh) return "Fixed rate"
  return "Set by Hyprland"
}

// The keyboard room's line: what turns it off, and FN-lock. The level is in
// the cells under it.
function keyboardState(level, idle, fnlockOn) {
  var parts = []
  if (!(level > 0)) parts.push("Off")
  else if (idle && idle.enabled) parts.push((idle.dimOnly ? "Dims" : "Off") + " after " + formatSeconds(idle.timeout))
  else parts.push("Stays lit")
  // A hyphen that does not break, so FN-lock never splits across lines.
  if (fnlockOn) parts.push("FN\u2011lock")
  return parts.join(" · ")
}

var ANIME_LEVELS = ["Off", "Low", "Med", "High"]

// The AniMe room's line and its 0..3 level, 0 being off.
function animeRoom(anime, enabled, brightness, awake) {
  if (!anime) return { level: 0, state: "" }
  var level = enabled ? Math.max(1, Math.min(3, brightness || 1)) : 0
  if (!enabled) return { level: 0, state: "Off" }
  var showing = awake === "RogLogoGlitch" ? "ROG logo" : "Banner"
  return { level: level, state: showing + " · " + ANIME_LEVELS[level] }
}

// The prompt under the title, a fact every few seconds. ctx: { ready,
// profile, ac, temps, fans, dgpu, gpuMode, battery, refresh }.
function heroPhrases(ctx) {
  if (!ctx) return ["Reading the laptop"]
  if (!ctx.ready) return ["asusd is not running"]
  var lines = []
  lines.push(profileInfo(ctx.profile).label + (ctx.ac ? " on the charger" : " on battery"))
  var t = ctx.temps || {}
  if (t.cpu !== null && t.cpu !== undefined) {
    var fan = maxFan({ fans: ctx.fans })
    lines.push("CPU at " + Math.round(t.cpu) + "°" + (fan ? ", fans at " + rpm(fan) + " rpm" : fan === 0 ? ", fans off" : ""))
  }
  if (ctx.gpuMode) lines.push(gpuModeInfo(ctx.gpuMode).label + " graphics, NVIDIA " + dgpuLabel(ctx.dgpu))
  var b = ctx.battery
  if (b && b.percent !== null && b.percent !== undefined) {
    var limited = b.limit && b.limit < 100
    if (ctx.ac && limited && b.percent >= b.limit - 1) lines.push("Battery held at " + b.limit + "% to spare it")
    else lines.push("Battery at " + b.percent + "%" + (limited ? ", stops at " + b.limit + "%" : ""))
  }
  if (ctx.refresh) lines.push("Screen at " + ctx.refresh + " Hz")
  lines.push("Scroll on the bar icon to change mode")
  if (ctx.model) lines.push(String(ctx.model).replace(/_.*$/, ""))
  return lines
}

// The room or page `openTab` opens: a room's key, "settings" or
// "fans-curve", "" for the rooms with none open, null for a name it does not
// know. The tab names from before the rooms still work.
var TAB_ROOMS = {
  main: "", rooms: "", power: "power", battery: "battery", fans: "fans", heat: "heat", cpu: "heat", temps: "heat", display: "display", graphics: "graphics",
  keyboard: "keyboard", lighting: "keyboard", keys: "keyboard", anime: "anime", system: "settings", settings: "settings",
  curve: "fans-curve", curves: "fans-curve", "fans-curve": "fans-curve"
}

function roomForTab(name) {
  var key = String(name || "").trim().toLowerCase()
  return TAB_ROOMS.hasOwnProperty(key) ? TAB_ROOMS[key] : null
}

// What the prompt says while a room is open: what its drawer holds.
function roomLine(room, profile) {
  if (room === "power") return "Pick a mode, or scroll on the bar icon"
  if (room === "heat") return "Warm from 70 °C, hot from 85 °C"
  if (room === "battery") return "Where charging stops, and Battery saver"
  if (room === "fans") return "Fan curves follow the mode, " + profileInfo(profile).label + " now"
  if (room === "display") return "The refresh rate and the panel's switches"
  if (room === "graphics") return "Switching the GPU mode restarts the laptop"
  if (room === "keyboard") return "When the light turns itself off, and FN-lock"
  if (room === "anime") return "What the lid shows, and when it rests"
  return ""
}

// The card the bar item opens on hover: a row per room with a reading, in
// the panel's tones. { key, name, icon, tone, level (0..100 or null),
// figure (pixel type), mark, dimmed }.
function hoverRows(status, ctx) {
  if (!status || !status.asusd) return []
  ctx = ctx || {}
  var rows = []
  var profile = profileInfo(ctx.profile || (status.profile && status.profile.active))
  var w = status.watts || {}
  rows.push({ key: "power", name: profile.label + " mode", icon: profile.pixel, tone: roomTone("power"), level: null,
              figure: w.igpu !== null && w.igpu !== undefined ? pixelWatts(w.igpu) : "", mark: ctx.speedHeld ? "zap" : "", dimmed: false })
  var t = status.temps || {}
  if (t.cpu !== null && t.cpu !== undefined)
    rows.push({ key: "cpu", name: "CPU", icon: "cpu", tone: roomTone("fans"), level: Math.max(0, Math.min(100, t.cpu)),
                figure: pixelTemp(t.cpu), mark: heat(t.cpu) === 2 ? "thermometer" : "", dimmed: false })
  if (status.dgpu) {
    var awake = t.gpu !== null && t.gpu !== undefined
    rows.push({ key: "gpu", name: "NVIDIA " + dgpuLabel(status.dgpu), icon: "gpu", tone: roomTone("graphics"),
                level: awake ? Math.max(0, Math.min(100, t.gpu)) : null, figure: awake ? pixelTemp(t.gpu) : "",
                mark: awake && heat(t.gpu) === 2 ? "thermometer" : "", dimmed: !awake })
  }
  var fan = maxFan(status)
  if (fan !== null) rows.push({ key: "fans", name: "Fans", icon: "fan", tone: roomTone("fans"), level: null, figure: rpm(fan), mark: "", dimmed: fan === 0 })
  var b = status.battery
  if (b && b.percent !== null && b.percent !== undefined) {
    var room = batteryRoom(b, status.ac, false)
    rows.push({ key: "battery", name: "Battery", icon: batteryPixel(b.percent), tone: roomTone("battery"), level: b.percent,
                figure: b.percent + "%", mark: room.mark, dimmed: false })
  }
  if (status.display && status.display.refresh)
    rows.push({ key: "display", name: "Screen", icon: "monitor", tone: roomTone("display"), level: null,
                figure: status.display.refresh + "Hz", mark: "", dimmed: false })
  return rows
}

// Every pixel icon this file names, for the test that checks Pixels.js has
// them all.
var MODEL_PIXELS = ["thermometer", "gpu", "fan", "cpu", "monitor", "battery", "battery-low", "battery-medium",
  "battery-full", "zap", "plug", "leaf", "speed-medium", "speed-fast", "snowflake", "wind", "undo",
  "binary", "eye", "sun", "moon", "power", "bed", "power-off"]

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
// anyModel: what wants the helper works without a CPU limit table (full speed).
function powerHelperNotice(power, wanted, anyModel) {
  if (!wanted || !power || (!power.supported && !anyModel) || power.helper === "ok") return null
  return { key: "power-helper", tone: "accent", icon: "󰌾", action: "power-setup", actionLabel: "Set up",
           text: power.helper === "outdated"
             ? "ROG Deck's power helper needs an update. It asks for your password once"
             : "The CPU limit, Wi-Fi power save and full speed need ROG Deck's power helper. It asks for your password once" }
}
