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
