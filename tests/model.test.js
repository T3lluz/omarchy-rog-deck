// Run with: node tests/model.test.js
const fs = require("fs")
const path = require("path")
const assert = require("assert")

const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8").replace(/^\.pragma library\s*/, "")
const Model = new Function(source + "\nreturn { parseStatus, normalizeProfile, profileInfo, profileChoices, steppedProfile, wheelSteps, fanConfirm, actionKind, SWATCHES, SWATCH_NAMES, heatLevels, heatOf, heat, temperature, watts, rpm, maxFan, dgpuLabel, gpuModes, gpuModeInfo, batteryLine, tooltip, defaultSettings, mergeSettings, cleanHex, auraEffects, nextAuraEffect, auraArgs, animeBuiltins, animeContent, refreshTarget, curveString, clampPoint, formatSeconds, barParts, BAR_STATS, PROFILES, GPU_MODES, FAN_PRESETS, ANIME_CONTENT, gpuConfirmText, gpuNotice, saverOverdrive, pptTriple, powerLimitWatts, limitCaption, limitApplied, batteryGpuNotice, powerHelperNotice, screenLevel, speedWanted, speedPlan, speedHint, pixelWatts, pixelTemp, batteryPixel, ROOM_TONES, roomTone, powerState, powerMark, batteryRoom, fanParts, fansState, graphicsState, displayState, keyboardState, animeRoom, heroPhrases, roomLine, roomForTab, hoverRows, MODEL_PIXELS, batteryFacts, fansLine, fanFacts, heatState, fanFigure }")()

// Trimmed from a real `bin/rog-deck status` on a GA402NV.
const status = {
  asusd: true,
  model: "ROG Zephyrus G14 GA402NV_GA402NV",
  ac: true,
  profile: { active: "power-saver", choices: ["power-saver", "balanced", "performance"], asusdAutoSwitch: false },
  temps: { cpu: 77.0, gpu: 65.0, gpuSource: "nvidia" },
  watts: { igpu: 8.8, dgpu: 6.18 },
  fans: { cpu: 3200, gpu: 3400, mid: null },
  battery: { percent: 76, status: "Charging", limit: 100, watts: 44.4 },
  dgpu: "active"
}

// parseStatus
assert.deepStrictEqual(Model.parseStatus(JSON.stringify(status) + "\n"), status)
assert.strictEqual(Model.parseStatus(""), null)
assert.strictEqual(Model.parseStatus("not json"), null)
assert.strictEqual(Model.parseStatus("42"), null)

// normalizeProfile
assert.strictEqual(Model.normalizeProfile("Silent"), "power-saver")
assert.strictEqual(Model.normalizeProfile("quiet"), "power-saver")
assert.strictEqual(Model.normalizeProfile("turbo"), "performance")
assert.strictEqual(Model.normalizeProfile(" balanced "), "balanced")

// profileInfo / profileChoices
assert.strictEqual(Model.profileInfo("performance").label, "Turbo")
assert.strictEqual(Model.profileInfo("custom").label, "Custom")
assert.strictEqual(Model.profileInfo("").label, "Unknown")
assert.deepStrictEqual(Model.profileChoices(status).map(p => p.key), ["power-saver", "balanced", "performance"])
assert.deepStrictEqual(Model.profileChoices({ profile: { choices: ["performance", "power-saver"] } }).map(p => p.key),
  ["power-saver", "performance"], "tiles follow our order, not the daemon's")
assert.deepStrictEqual(Model.profileChoices(null), [])

for (const hex of Model.SWATCHES) assert.ok(Model.SWATCH_NAMES[hex], "swatch " + hex + " has a name for its tooltip")

// Queued actions of one kind collapse to the newest; one-offs never do.
assert.strictEqual(Model.actionKind(["kbd", "idle-off", "0"]), Model.actionKind(["kbd", "idle-on"]))
assert.strictEqual(Model.actionKind(["power", "limit", "20"]), Model.actionKind(["power", "off"]))
assert.strictEqual(Model.actionKind(["profile", "performance"]), "profile")
assert.notStrictEqual(Model.actionKind(["fans", "set", "balanced", "cpu", "x"]), Model.actionKind(["fans", "set", "balanced", "gpu", "x"]))
for (const once of [["battery", "oneshot"], ["fans", "preset", "balanced", "cool"], ["fans", "reset", "balanced"], ["aura"], ["takeover"], ["power", "setup"]])
  assert.strictEqual(Model.actionKind(once), "", once.join(" ") + " always runs")

// The wheel: a notch is a step, a touchpad's small deltas add up to one.
assert.deepStrictEqual(Model.wheelSteps(0, 120), { steps: 1, acc: 0 })
assert.deepStrictEqual(Model.wheelSteps(0, -120), { steps: -1, acc: 0 })
let wheel = { steps: 0, acc: 0 }, stepped = 0
for (let i = 0; i < 14; i++) { wheel = Model.wheelSteps(wheel.acc, 15); stepped += wheel.steps }
assert.strictEqual(stepped, 1, "fourteen touchpad events of 15 make one notch")
assert.strictEqual(wheel.acc, 90)
assert.deepStrictEqual(Model.wheelSteps(90, -100), { steps: 0, acc: -10 }, "turning back cancels a part notch")
assert.deepStrictEqual(Model.wheelSteps(0, 250), { steps: 2, acc: 10 })

// A fan pick asks first when it throws a curve away.
assert.strictEqual(Model.fanConfirm("balanced", "reset", false).confirmText, "Reset", "reset always asks")
assert.ok(/Balanced/.test(Model.fanConfirm("balanced", "reset", true).message))
assert.strictEqual(Model.fanConfirm("balanced", "cool", false), null, "a preset with the custom curve off just goes")
assert.strictEqual(Model.fanConfirm("performance", "cool", true).confirmText, "Use Cool")
assert.strictEqual(Model.fanConfirm("balanced", "nonsense", true), null)

// steppedProfile stops at the ends
assert.strictEqual(Model.steppedProfile(status, 120), "balanced")
assert.strictEqual(Model.steppedProfile(status, -120), "")
const turbo = Object.assign({}, status, { profile: Object.assign({}, status.profile, { active: "performance" }) })
assert.strictEqual(Model.steppedProfile(turbo, 120), "")
assert.strictEqual(Model.steppedProfile(turbo, -120), "balanced")
assert.strictEqual(Model.steppedProfile(status, 0), "")

// heat and formatting
assert.strictEqual(Model.heat(null), 0)
assert.strictEqual(Model.heat(69.9), 0)
assert.strictEqual(Model.heat(70), 1)
assert.strictEqual(Model.heat(85), 2)
// Hysteresis: up at once, down only 3 °C under the step.
assert.strictEqual(Model.heat(84, 2), 2, "84 stays hot after 85")
assert.strictEqual(Model.heat(82.5, 2), 2)
assert.strictEqual(Model.heat(82, 2), 1, "82 is warm again")
assert.strictEqual(Model.heat(68, 1), 1)
assert.strictEqual(Model.heat(66, 2), 0, "a big drop goes straight down")
assert.strictEqual(Model.heat(71, 0), 1, "climbing is at once")
let levels = {}
const temps = [84, 85, 84, 85, 84, 83, 82, 81]
const words = temps.map(c => { levels = Model.heatLevels({ cpu: c }, levels); return Model.fanParts({ temps: { cpu: c }, fans: { cpu: 3000 }, heat: levels })[0].warmth })
assert.deepStrictEqual(words, ["Warm", "Hot", "Hot", "Hot", "Hot", "Hot", "Warm", "Warm"], "a reading on the step doesn't flip each poll")
assert.strictEqual(Model.heatOf({ temps: { cpu: 84 } }, "cpu"), 1, "without held levels, the plain steps")
assert.strictEqual(Model.heatOf({ temps: { cpu: 84 }, heat: { cpu: 2 } }, "cpu"), 2)
assert.strictEqual(Model.temperature(76.6), "77°")
assert.strictEqual(Model.temperature(null), "—")
assert.strictEqual(Model.watts(6.18), "6.2 W")
assert.strictEqual(Model.watts(44.4), "44 W")
assert.strictEqual(Model.watts(null), "")
assert.strictEqual(Model.rpm(3200), "3.2k")
assert.strictEqual(Model.rpm(0), "off")
assert.strictEqual(Model.rpm(950), "950")
assert.strictEqual(Model.rpm(null), "—")
assert.strictEqual(Model.maxFan(status), 3400)
assert.strictEqual(Model.maxFan({ fans: { cpu: null, gpu: null } }), null)
assert.strictEqual(Model.dgpuLabel("suspended"), "asleep")
assert.strictEqual(Model.batteryLine(status.battery, true), "76% +44 W")
assert.strictEqual(Model.batteryLine(status.battery, false), "76% −44 W")
assert.strictEqual(Model.batteryLine(null, true), "")

// GPU modes keep tile order and drop what the laptop lacks
assert.deepStrictEqual(Model.gpuModes({ modes: ["dedicated", "hybrid"] }).map(m => m.value), ["hybrid", "dedicated"])
assert.deepStrictEqual(Model.gpuModes(null), [])
assert.strictEqual(Model.gpuModeInfo("dedicated").label, "Dedicated")
assert.strictEqual(Model.gpuModeInfo("vfio").label, "Vfio")

// tooltip
assert.strictEqual(Model.tooltip(null), "ROG Deck: reading the laptop…")
assert.strictEqual(Model.tooltip({ asusd: false }), "ROG Deck: asusd is not running")
assert.strictEqual(Model.tooltip(status), "Silent mode\nCPU 77°  GPU 65°\nFans 3.2k / 3.4k rpm\nBattery 76% +44 W")

// settings
const merged = Model.mergeSettings('{"kbdIdle":{"timeout":30,"enabled":"yes"},"refresh":"auto","bogus":1,"anime":{"content":"static"}}')
assert.strictEqual(merged.anime, undefined, "old AniMe image settings are dropped")
assert.strictEqual(merged.kbdIdle.timeout, 30)
assert.strictEqual(merged.kbdIdle.enabled, true, "wrong-typed values keep the default")
assert.strictEqual(merged.refresh, "auto")
assert.strictEqual(merged.bogus, undefined)
assert.deepStrictEqual(Model.mergeSettings("not json"), Model.defaultSettings())
assert.strictEqual(Model.cleanHex("#79818A\n"), "79818a")
assert.strictEqual(Model.cleanHex("zz"), "")

// keyboard effects: a white-only keyboard gets Static alone
assert.deepStrictEqual(Model.auraEffects([0, 1, 2, 3, 10], false).map(e => e.key), ["static"])
assert.deepStrictEqual(Model.auraEffects([0, 1, 2, 3, 10], true).map(e => e.key), ["static", "breathe", "pulse", "rainbow-cycle", "rainbow-wave"])
assert.deepStrictEqual(Model.auraEffects([0], true).map(e => e.key), ["static"])
assert.strictEqual(Model.nextAuraEffect("static", [0, 1, 10], false), "static")
assert.strictEqual(Model.nextAuraEffect("static", [0, 1, 10], true), "breathe")
assert.strictEqual(Model.nextAuraEffect("pulse", [0, 1, 10], true), "static")
assert.strictEqual(Model.nextAuraEffect("x", [], false), "")
const light = Model.defaultSettings().kbdLight
assert.deepStrictEqual(Model.auraArgs(light, "798186"), ["static", "--colour", "ffffff"], "white keyboard always gets white")
assert.deepStrictEqual(Model.auraArgs(Object.assign({}, light, { rgb: true }), "798186"), ["static", "--colour", "798186"])
assert.deepStrictEqual(Model.auraArgs(Object.assign({}, light, { rgb: true, followTheme: false, colour: "ff0033" }), "798186"), ["static", "--colour", "ff0033"])
assert.deepStrictEqual(Model.auraArgs(Object.assign({}, light, { effect: "breathe", speed: "high" }), ""),
  ["breathe", "--colour", "ffffff", "--colour2", "000000", "--speed", "high"])
assert.deepStrictEqual(Model.auraArgs(Object.assign({}, light, { effect: "rainbow-wave", rgb: true }), ""),
  ["rainbow-wave", "--speed", "med", "--direction", "right"])
assert.strictEqual(Model.auraArgs(Object.assign({}, light, { effect: "nope" }), ""), null)

// anime
assert.deepStrictEqual(Model.animeBuiltins(null, "sleep", "BannerSwipe"),
  { boot: "GlitchConstruction", awake: "BinaryBannerScroll", sleep: "BannerSwipe", shutdown: "SeeYa" })
const anime = { builtinsEnabled: true, builtins: { boot: "StaticEmergence", awake: "RogLogoGlitch", sleep: "Starfield", shutdown: "GlitchOut" } }
assert.strictEqual(Model.animeBuiltins(anime, "shutdown", "SeeYa").awake, "RogLogoGlitch", "other slots keep their value")
assert.strictEqual(Model.animeContent(anime), "logo")
assert.strictEqual(Model.animeContent({ builtins: { awake: "BinaryBannerScroll" } }), "banner")
assert.strictEqual(Model.animeContent(null), "banner")

assert.strictEqual(Model.formatSeconds(45), "45 s")
assert.strictEqual(Model.formatSeconds(60), "1 min")
assert.strictEqual(Model.formatSeconds(90), "1 min 30 s")

// refresh rate
const display = { rates: [60, 165] }
assert.strictEqual(Model.refreshTarget("auto", display, true), 165)
assert.strictEqual(Model.refreshTarget("auto", display, false), 60)
assert.strictEqual(Model.refreshTarget("auto", { rates: [120, 240] }, false), 120)
assert.strictEqual(Model.refreshTarget("60", display, true), 60)
assert.strictEqual(Model.refreshTarget("144", display, true), 0)
assert.strictEqual(Model.refreshTarget(null, display, true), 0)
// Battery saver: 60 Hz on battery whatever is picked; back to the pick, or the top rate, on the charger.
assert.strictEqual(Model.refreshTarget("165", display, false, true), 60)
assert.strictEqual(Model.refreshTarget(null, display, false, true), 60)
assert.strictEqual(Model.refreshTarget(null, display, true, true), 165)
assert.strictEqual(Model.refreshTarget("auto", display, true, true), 165)
assert.strictEqual(Model.refreshTarget("60", display, true, true), 60)
assert.strictEqual(Model.refreshTarget(null, display, false, false), 0)
assert.strictEqual(Model.refreshTarget(null, null, false, true), 0)

// fan curves
const pts = [{ t: 40, p: 10 }, { t: 50, p: 20 }, { t: 60, p: 30 }]
assert.strictEqual(Model.curveString(pts), "40:10,50:20,60:30")
assert.deepStrictEqual(Model.clampPoint(pts, 1, 70, 120), { t: 60, p: 100 }, "stays under the next point and 100 %")
assert.deepStrictEqual(Model.clampPoint(pts, 1, 30, -5), { t: 40, p: 0 })

// bar stats
const barStatus = Object.assign({}, status, { display: { refresh: 165, rates: [60, 165] } })
assert.deepStrictEqual(Model.barParts(barStatus, []), [])
assert.deepStrictEqual(Model.barParts(null, ["cpuTemp"]), [])
assert.deepStrictEqual(Model.barParts({ asusd: false }, ["cpuTemp"]), [])
// The bar writes figures in the pixel type, each after its pixel icon, and
// only the mode's name as a word in the bar's own font.
const allStats = ["mode", "cpuTemp", "gpuTemp", "fans", "power", "dgpu", "battery", "refresh"]
const parts = Model.barParts(barStatus, allStats)
assert.deepStrictEqual(parts.map(p => p.text), ["", "77°", "65°", "3.4k", "8.8W", "6.2W", "76%", "165Hz"])
assert.deepStrictEqual(parts.map(p => p.icon), ["", "thermometer", "gpu", "fan", "cpu", "gpu", "battery-full", "monitor"])
assert.deepStrictEqual(parts.map(p => p.word), ["Silent", "", "", "", "", "", "", ""])
assert.deepStrictEqual(Model.barParts(barStatus, ["refresh", "cpuTemp"]).map(p => p.stat), ["refresh", "cpuTemp"], "keeps the picked order")
assert.strictEqual(Model.barParts(barStatus, ["cpuTemp"])[0].hot, false)
assert.strictEqual(Model.barParts(Object.assign({}, barStatus, { temps: { cpu: 91, gpu: 60 } }), ["cpuTemp"])[0].hot, true, "85 °C and up takes the urgent colour")
const asleep = Object.assign({}, barStatus, { ac: false, dgpu: "suspended", temps: { cpu: 50, gpu: null }, watts: { igpu: 12.4, dgpu: null } })
assert.deepStrictEqual(Model.barParts(asleep, ["gpuTemp", "dgpu", "power", "battery"]).map(p => p.text),
  ["Zz", "12W", "76%"], "no GPU temperature while it sleeps")
assert.strictEqual(Model.barParts(Object.assign({}, asleep, { dgpu: "absent" }), ["dgpu"])[0].text, "off")
assert.strictEqual(new Set(Model.BAR_STATS.map(s => s.key)).size, Model.BAR_STATS.length)
const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, "..", "manifest.json"), "utf8"))
assert.deepStrictEqual(manifest.barWidget.schema.map(e => e.key), Model.BAR_STATS.map(s => s.key), "manifest offers every bar stat")
for (const entry of manifest.barWidget.schema) assert.strictEqual(manifest.barWidget.defaults[entry.key], entry.defaultValue, entry.key + " default agrees")

// Each mode has the glyph Omarchy's power menu gives it: leaf, gauge, speedometer.
assert.deepStrictEqual(Model.PROFILES.map(p => p.label), ["Silent", "Balanced", "Turbo"])
assert.deepStrictEqual(Model.PROFILES.map(p => p.icon.codePointAt(0)), [0xf032a, 0xf029a, 0xf04c5])
// In pixels: the leaf, then a dial whose needle swings from upright to fast.
assert.deepStrictEqual(Model.PROFILES.map(p => p.pixel), ["leaf", "speed-medium", "speed-fast"])

// ---- rooms

// Neighbouring rooms never share a tone, beside or above.
const tone = Model.roomTone
// What each quarter of the panel's width holds, row by row; the fans and
// battery tiles stack, so the CPU and GPU row is written twice.
const layout = [["power", "power", "power", "power"], ["heat", "heat", "heat", "fans"], ["heat", "heat", "heat", "battery"],
  ["graphics", "graphics", "display", "display"], ["keyboard", "keyboard", "anime", "anime"]]
for (let r = 0; r < layout.length; r++) {
  for (let c = 0; c < layout[r].length; c++) {
    const here = tone(layout[r][c])
    assert.ok(["blue", "green", "cyan", "yellow", "magenta"].includes(here), layout[r][c] + " has a tone")
    if (c > 0 && layout[r][c] !== layout[r][c - 1])
      assert.notStrictEqual(here, tone(layout[r][c - 1]), layout[r][c] + " differs from its left neighbour")
    if (r > 0 && layout[r][c] !== layout[r - 1][c])
      assert.notStrictEqual(here, tone(layout[r - 1][c]), layout[r][c] + " differs from the room above")
  }
}

// Power: what the charger and the mode's own option do.
const fast = { epp: "performance", held: true }
assert.strictEqual(Model.powerState({ ac: true, profile: "balanced", speed: fast, speedOn: true }), "Plugged in · full speed")
assert.strictEqual(Model.powerState({ ac: true, profile: "balanced", speed: { epp: "balance_performance" }, speedOn: true }), "Plugged in · full speed soon")
assert.strictEqual(Model.powerState({ ac: false, profile: "balanced", speed: fast, speedOn: true, saverActive: true }), "On battery · Battery saver")
assert.strictEqual(Model.powerState({ ac: false, profile: "power-saver", limitShown: true, limit: { enabled: true, watts: 18 } }), "On battery · held to 18 W")
assert.strictEqual(Model.powerMark({ ac: true, profile: "balanced", speed: fast }), "zap")
assert.strictEqual(Model.powerMark({ ac: false, profile: "balanced", speed: fast }), "")

// Battery: a mark for every state that is not plain discharging, and low
// never on colour alone.
assert.deepStrictEqual(Model.batteryRoom({ percent: 64, status: "Charging", limit: 80, watts: 31.2 }, true, false),
  { level: 64, state: "Charging", mark: "zap", limit: 80 })
assert.deepStrictEqual(Model.batteryRoom({ percent: 80, status: "Not charging", limit: 80, watts: 0 }, true, false),
  { level: 80, state: "Held at 80%", mark: "plug", limit: 80 })
assert.strictEqual(Model.batteryRoom({ percent: 100, status: "Full", limit: 100 }, true, false).state, "Full")
assert.deepStrictEqual(Model.batteryRoom({ percent: 12, status: "Discharging", limit: 100, watts: 9.4 }, false, true),
  { level: 12, state: "Saver on", mark: "battery-low", limit: -1 })
assert.strictEqual(Model.batteryRoom({ percent: 50, status: "Discharging", watts: 9.4 }, false, false).state, "On battery")
assert.strictEqual(Model.batteryRoom(null, true, false).level, null)
assert.deepStrictEqual(Model.batteryFacts({ percent: 64, watts: 31.2, status: "Charging" }, true), [{ label: "Power", value: "+31 W" }, { label: "State", value: "Charging" }])
assert.deepStrictEqual(Model.batteryFacts({ percent: 64, watts: 7.25 }, false), [{ label: "Power", value: "−7.3 W" }])
assert.deepStrictEqual(Model.batteryFacts({ percent: 90, watts: 0 }, true)[0], { label: "Power", value: "0 W" })
assert.deepStrictEqual([5, 15, 40, 60, 100, null].map(Model.batteryPixel),
  ["battery-low", "battery-low", "battery-medium", "battery-full", "battery-full", "battery"])

// Fans: the GPU reads nothing while it sleeps, and says so.
const fanned = Model.fanParts({ temps: { cpu: 88, gpu: null }, fans: { cpu: 3400, gpu: 0 }, dgpu: "suspended" })
assert.deepStrictEqual(fanned.map(p => [p.key, p.state, p.hot]), [["cpu", "3.4k rpm", true], ["gpu", "asleep · fan off", false]])
assert.deepStrictEqual(fanned.map(p => p.warmth), ["Hot", "Asleep"])
assert.deepStrictEqual(Model.fanParts({ temps: { cpu: 64, gpu: 74 }, fans: { cpu: 2000, gpu: 2000 }, dgpu: "active" }).map(p => p.warmth), ["Cool", "Warm"])
assert.strictEqual(Model.fansState(true, true), "Custom curve")
assert.strictEqual(Model.heatState({ cpu: 61, gpu: null }), "Cool")
assert.strictEqual(Model.heatState({ cpu: 66, gpu: 74 }), "Warm", "the hotter of the two")
assert.strictEqual(Model.heatState({ cpu: 96, gpu: 70 }), "Hot")
assert.strictEqual(Model.heatState({}), "No reading")
assert.strictEqual(Model.roomForTab("cpu"), "heat")
assert.strictEqual(Model.fansLine(4100, false, true), "4.1k rpm")
assert.deepStrictEqual(Model.fanFigure(4349), { text: "4.3", suffix: "k" })
assert.deepStrictEqual(Model.fanFigure(10000), { text: "10.0", suffix: "k" })
assert.deepStrictEqual(Model.fanFigure(850), { text: "850", suffix: "" })
assert.deepStrictEqual(Model.fanFigure(0), { text: "0", suffix: "" })
assert.deepStrictEqual(Model.fanFigure(null), { text: "", suffix: "" })
assert.strictEqual(Model.fansLine(0, true, true), "Stopped · custom curve")
assert.strictEqual(Model.fansLine(null, false, false), "No fan reading")
assert.deepStrictEqual(Model.fanFacts({ temps: { cpu: 88.4, gpu: null }, fans: { cpu: 3400, gpu: 0 }, dgpu: "suspended" }),
  [{ label: "CPU", value: "88 °C, 3.4k rpm" }, { label: "GPU", value: "asleep, fan off" }])
assert.strictEqual(Model.fansState(false, false), "Reading fan curves")

// Graphics, display, keyboard, AniMe lines.
assert.strictEqual(Model.graphicsState({ mode: "hybrid" }, "active", 12.3, "hybrid"), "NVIDIA awake", "its draw is the figure")
assert.strictEqual(Model.graphicsState({ mode: "hybrid" }, "suspended", null, "integrated"), "Integrated on restart")
assert.strictEqual(Model.displayState("auto", false, true), "Auto rate")
assert.strictEqual(Model.displayState("auto", true, false), "Battery saver")
assert.strictEqual(Model.keyboardState(2, { enabled: true, timeout: 60, dimOnly: false }, true), "Off after 1 min · Fn\u00a0lock")
assert.strictEqual(Model.keyboardState(1, { enabled: true, timeout: 30, dimOnly: true }, false), "Dims after 30 s")
assert.strictEqual(Model.keyboardState(3, { enabled: false }, false), "Stays lit")
assert.strictEqual(Model.keyboardState(0, { enabled: true, timeout: 60 }, false), "Off")
assert.deepStrictEqual(Model.animeRoom({}, false, 2, ""), { level: 0, state: "Off" })
assert.deepStrictEqual(Model.animeRoom({}, true, 3, "RogLogoGlitch"), { level: 3, state: "ROG logo · High" })

// The prompt: facts in turn, an open room's own line, and asusd missing.
const phrases = Model.heroPhrases({ ready: true, profile: "balanced", ac: true, temps: { cpu: 61.4 }, fans: { cpu: 2100, gpu: 0 },
  dgpu: "suspended", gpuMode: "hybrid", battery: { percent: 80, limit: 80 }, refresh: 165, model: "ROG Zephyrus G14 GA402NV_GA402NV" })
assert.deepStrictEqual(phrases, ["Balanced on the charger", "CPU at 61°, fans at 2.1k rpm", "Hybrid graphics, NVIDIA asleep",
  "Battery held at 80% to spare it", "Screen at 165 Hz", "Scroll on the bar icon to change mode", "ROG Zephyrus G14 GA402NV"])
assert.deepStrictEqual(Model.heroPhrases({ ready: false }), ["asusd is not running"])
for (const room of ["power", "heat", "battery", "fans", "display", "graphics", "keyboard", "anime"])
  assert.ok(Model.roomLine(room, "balanced").length > 0, room + " says what its drawer holds")

// openTab still takes the old tab names.
assert.strictEqual(Model.roomForTab("lighting"), "keyboard")
assert.strictEqual(Model.roomForTab("System"), "settings")
assert.strictEqual(Model.roomForTab("main"), "")
assert.strictEqual(Model.roomForTab("curve"), "fans-curve")
assert.strictEqual(Model.roomForTab("nope"), null)

// The hover card: a row per reading, tones by room, figures the pixel type can draw.
const rows = Model.hoverRows(Object.assign({}, barStatus, { profile: { active: "balanced" } }), { profile: "balanced", speedHeld: true })
assert.deepStrictEqual(rows.map(r => r.key), ["power", "cpu", "gpu", "fans", "battery", "display"])
assert.strictEqual(rows[0].mark, "zap")
assert.strictEqual(rows[2].level, 65)
assert.deepStrictEqual(Model.hoverRows(asleep, {}).find(r => r.key === "gpu"), { key: "gpu", name: "NVIDIA asleep", icon: "gpu", tone: "green", level: null, figure: "", mark: "", dimmed: true })
assert.deepStrictEqual(Model.hoverRows({ asusd: false }, {}), [])

// Every bar stat has a tile icon and a short label for the two-column grid.
for (const s of Model.BAR_STATS) assert.ok(s.icon && s.label.length <= 14, s.key + " fits a half-width tile")
assert.strictEqual(Model.defaultSettings().updates.autoCheck, true)
assert.strictEqual(Model.mergeSettings('{"updates":{"autoCheck":false}}').updates.autoCheck, false)

// GPU switch prompt and the restart banner
assert.strictEqual(Model.gpuConfirmText({ needsSetup: true }, "integrated"),
  "Switch to Integrated GPU mode? ROG Deck first installs supergfxctl, which asks for your password. The laptop then restarts, closing open windows.")
assert.strictEqual(Model.gpuConfirmText({ needsSetup: true }, "hybrid"), "Switch to Hybrid GPU mode? The laptop then restarts, closing open windows.")
assert.strictEqual(Model.gpuNotice({ mode: "hybrid" }, "hybrid"), null)
assert.strictEqual(Model.gpuNotice(null, "hybrid"), null)
assert.strictEqual(Model.gpuNotice({ mode: "dedicated" }, "integrated").text, "Restart to finish switching to Integrated GPU mode")

// Battery saver and panel overdrive
assert.deepStrictEqual(Model.saverOverdrive(true, 1, null), { set: 0, remember: 1 })
assert.deepStrictEqual(Model.saverOverdrive(true, 0, 1), { set: null })
assert.deepStrictEqual(Model.saverOverdrive(false, 0, 1), { set: 1 })
assert.deepStrictEqual(Model.saverOverdrive(false, 0, 0), { set: null })
assert.deepStrictEqual(Model.saverOverdrive(false, 1, 1), { set: null })
assert.deepStrictEqual(Model.saverOverdrive(false, 0, null), { set: null })
assert.deepStrictEqual(Model.saverOverdrive(true, null, 1), { set: null })
assert.deepStrictEqual(Model.defaultSettings().saver, { enabled: false, screen: true, wifi: true, overdriveAc: null })
const saved = Model.mergeSettings('{"saver":{"enabled":true,"overdriveAc":1},"powerLimit":{"enabled":true,"watts":20}}')
assert.strictEqual(saved.saver.enabled, true)
assert.strictEqual(saved.saver.overdriveAc, 1)
assert.strictEqual(saved.saver.screen, true)
assert.deepStrictEqual(saved.powerLimit, { enabled: true, watts: 20 })
assert.deepStrictEqual(Model.mergeSettings('{"powerLimit":{"watts":"lots"}}').powerLimit, { enabled: false, watts: 15 })

assert.strictEqual(Model.screenLevel(true, { screen: true }), 3)
assert.strictEqual(Model.screenLevel(true, { screen: false }), 0)
assert.strictEqual(Model.screenLevel(false, { screen: true }), 0)

// CPU limit: the GA402NV's ranges on battery and on the charger
const dc = { spl: [15, 35], sppt: [25, 35], fppt: [35, 65] }
const ac = { spl: [15, 80], sppt: [25, 80], fppt: [35, 80] }
assert.deepStrictEqual(Model.pptTriple(15, dc), { spl: 15, sppt: 25, fppt: 35 })
assert.deepStrictEqual(Model.pptTriple(28, dc), { spl: 28, sppt: 28, fppt: 35 })
assert.deepStrictEqual(Model.pptTriple(35, dc), { spl: 35, sppt: 35, fppt: 35 })
assert.deepStrictEqual(Model.pptTriple(10, dc), { spl: 15, sppt: 25, fppt: 35 })
assert.deepStrictEqual(Model.pptTriple(99, dc), { spl: 35, sppt: 35, fppt: 65 })
assert.deepStrictEqual(Model.pptTriple(30, ac), { spl: 30, sppt: 30, fppt: 35 })
assert.strictEqual(Model.pptTriple(15, null), null)
const power = { supported: true, helper: "ok", slider: [15, 35], ranges: dc }
const limitOn = { powerLimit: { enabled: true, watts: 20 } }
assert.strictEqual(Model.powerLimitWatts(limitOn, "power-saver", power), 20)
assert.strictEqual(Model.powerLimitWatts(limitOn, "balanced", power), 0)
assert.strictEqual(Model.powerLimitWatts(limitOn, "performance", power), 0)
assert.strictEqual(Model.powerLimitWatts({ powerLimit: { enabled: false, watts: 20 } }, "power-saver", power), 0)
assert.strictEqual(Model.powerLimitWatts({ powerLimit: { enabled: true, watts: 5 } }, "power-saver", power), 15)
assert.strictEqual(Model.powerLimitWatts({ powerLimit: { enabled: true, watts: 50 } }, "power-saver", power), 35)
assert.strictEqual(Model.powerLimitWatts(limitOn, "power-saver", { supported: false }), 0)
assert.strictEqual(Model.limitCaption({ spl: 15, sppt: 25, fppt: 35 }), "15 W sustained · boosts to 25 / 35 W")
assert.strictEqual(Model.limitCaption({ spl: 28, sppt: 28, fppt: 35 }), "28 W sustained · boosts to 28 / 35 W")
assert.strictEqual(Model.limitCaption({ spl: 20, sppt: 25, fppt: 25 }), "20 W sustained · boosts to 25 W")
assert.strictEqual(Model.limitCaption({ spl: 35, sppt: 35, fppt: 35 }), "35 W, boosts included")
assert.strictEqual(Model.limitApplied({ spl: 15, sppt: 25, fppt: 35, ac: false }, { spl: 15, sppt: 25, fppt: 35 }, false), true)
assert.strictEqual(Model.limitApplied({ spl: 15, sppt: 25, fppt: 35, ac: true }, { spl: 15, sppt: 25, fppt: 35 }, false), false)
assert.strictEqual(Model.limitApplied(null, { spl: 15, sppt: 25, fppt: 35 }, false), false)

// Battery banners
const hybrid = { mode: "hybrid", modes: ["integrated", "hybrid", "dedicated"] }
assert.strictEqual(Model.batteryGpuNotice(hybrid, "hybrid", true, true).action, "integrated")
assert.strictEqual(Model.batteryGpuNotice(hybrid, "integrated", true, true), null)
assert.strictEqual(Model.batteryGpuNotice(hybrid, "hybrid", false, true), null)
assert.strictEqual(Model.batteryGpuNotice(hybrid, "hybrid", true, false), null)
assert.strictEqual(Model.batteryGpuNotice({ mode: "integrated", modes: ["integrated", "hybrid"] }, "integrated", true, true), null)
assert.strictEqual(Model.powerHelperNotice({ supported: true, helper: "missing" }, true).action, "power-setup")
assert.ok(Model.powerHelperNotice({ supported: true, helper: "outdated" }, true).text.indexOf("update") !== -1)
assert.strictEqual(Model.powerHelperNotice({ supported: true, helper: "ok" }, true), null)
assert.strictEqual(Model.powerHelperNotice({ supported: true, helper: "missing" }, false), null)
assert.strictEqual(Model.powerHelperNotice({ supported: false, helper: "missing" }, true), null)

// Update wording and banners are the panel kit's: tests/update.test.js.


// Full speed: on the charger in Balanced. Turbo's governor already does it; Silent and battery keep their own.
const speedOn = { fullSpeed: { enabled: true } }
assert.deepStrictEqual(Model.defaultSettings().fullSpeed, { enabled: true })
assert.strictEqual(Model.mergeSettings('{"fullSpeed":{"enabled":false}}').fullSpeed.enabled, false)
assert.strictEqual(Model.speedWanted(speedOn, "balanced", true), true)
assert.strictEqual(Model.speedWanted(speedOn, "performance", true), false)
assert.strictEqual(Model.speedWanted(speedOn, "power-saver", true), false)
assert.strictEqual(Model.speedWanted(speedOn, "balanced", false), false)
assert.strictEqual(Model.speedWanted({ fullSpeed: { enabled: false } }, "balanced", true), false)
assert.strictEqual(Model.speedWanted({}, "balanced", true), false)

// Wanted: "on" until the preference is there and held.
assert.strictEqual(Model.speedPlan(speedOn, "balanced", true, { epp: "balance_performance", held: false }), "on")
assert.strictEqual(Model.speedPlan(speedOn, "balanced", true, { epp: "balance_power", held: true }), "on",
  "power-profiles-daemon wrote its own again")
assert.strictEqual(Model.speedPlan(speedOn, "balanced", true, { epp: "mixed", held: true }), "on",
  "a write that stopped partway")
assert.strictEqual(Model.speedPlan(speedOn, "balanced", true, { epp: "performance", held: false }), "on",
  "left in place by a logout: claimed again so it can be handed back")
assert.strictEqual(Model.speedPlan(speedOn, "balanced", true, { epp: "performance", held: true }), "")
// A CPU driver with no energy preference: nothing to do either way.
assert.strictEqual(Model.speedPlan(speedOn, "balanced", true, { epp: null, held: false }), "")
assert.strictEqual(Model.speedPlan(speedOn, "balanced", false, { epp: null, held: true }), "")
assert.strictEqual(Model.speedPlan(speedOn, "balanced", true, null), "")
// Not wanted: "off" only for a preference an earlier "on" set.
assert.strictEqual(Model.speedPlan(speedOn, "balanced", false, { epp: "performance", held: true }), "off")
assert.strictEqual(Model.speedPlan(speedOn, "power-saver", true, { epp: "power", held: true }), "off")
assert.strictEqual(Model.speedPlan(speedOn, "performance", true, { epp: "performance", held: true }), "off",
  "Turbo holds it itself, so the note is dropped")
assert.strictEqual(Model.speedPlan(speedOn, "performance", true, { epp: "performance", held: false }), "")
assert.strictEqual(Model.speedPlan({ fullSpeed: { enabled: false } }, "balanced", true, { epp: "performance", held: true }), "off")
assert.strictEqual(Model.speedPlan(null, "balanced", true, { epp: "performance", held: true }), "off",
  "no working helper: planned as switched off, so what is held goes back")
assert.strictEqual(Model.speedPlan(null, "balanced", true, { epp: "balance_performance", held: false }), "")
assert.strictEqual(Model.speedPlan(speedOn, "balanced", false, { epp: "performance", held: false }), "",
  "a preference someone else set is left alone")

const speedDoes = "On the charger, the CPU clocks up at once, as in Turbo, instead of ramping"
assert.strictEqual(Model.speedHint(true, "ok", true, "performance"), "On now. The CPU clocks up at once instead of ramping")
assert.strictEqual(Model.speedHint(true, "ok", true, "balance_power"), speedDoes, "not in place yet, so not claimed")
assert.strictEqual(Model.speedHint(true, "ok", false, "balance_power"), "Waiting for the charger. On battery the mode's own setting applies")
assert.strictEqual(Model.speedHint(false, "ok", true, "balance_performance"), speedDoes)
assert.strictEqual(Model.speedHint(false, "missing", true, "balance_performance"), speedDoes + ". Asks for your password once")
// Saved on without a working helper: the switch shows off and says why.
assert.strictEqual(Model.speedHint(true, "missing", true, "balance_performance"),
  "Off until ROG Deck's power helper is set up. Click to set it up. Asks for your password once")
assert.strictEqual(Model.speedHint(true, "outdated", true, "balance_performance"),
  "Off until ROG Deck's power helper is updated. Click to update it. Asks for your password once")
assert.ok(Model.powerHelperNotice({ supported: true, helper: "missing" }, true).text.indexOf("full speed") !== -1)
// A laptop without a CPU limit table is only asked when full speed wants the helper.
assert.strictEqual(Model.powerHelperNotice({ supported: false, helper: "outdated" }, true), null)
assert.ok(Model.powerHelperNotice({ supported: false, helper: "outdated" }, true, true).text.indexOf("update") !== -1)
assert.strictEqual(Model.powerHelperNotice({ supported: false, helper: "ok" }, true, true), null)

console.log("model tests passed")
