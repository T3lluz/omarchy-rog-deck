// Run with: node tests/model.test.js
const fs = require("fs")
const path = require("path")
const assert = require("assert")

const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8").replace(/^\.pragma library\s*/, "")
const Model = new Function(source + "\nreturn { parseStatus, normalizeProfile, profileInfo, profileChoices, steppedProfile, heat, temperature, watts, rpm, maxFan, dgpuLabel, gpuModes, gpuModeInfo, batteryLine, tooltip, defaultSettings, mergeSettings, cleanHex, auraEffects, nextAuraEffect, auraArgs, animeBuiltins, animeContent, refreshTarget, curveString, clampPoint, formatSeconds, barParts, BAR_STATS, PROFILES, gpuConfirmText, gpuNotice, saverOverdrive, pptTriple, powerLimitWatts, limitCaption, limitApplied, batteryGpuNotice, powerHelperNotice }")()

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
assert.deepStrictEqual(Model.barParts(barStatus, ["mode", "cpuTemp", "gpuTemp", "fans", "power", "dgpu", "battery", "refresh"]).map(p => p.text),
  ["Silent", "󰔏 77°", "󰢮 65°", "󰈐 3.4k", "󰻠 8.8 W", "󰢮 6.2 W", "󰂄 76%", "󰍹 165 Hz"])
assert.deepStrictEqual(Model.barParts(barStatus, ["refresh", "cpuTemp"]).map(p => p.stat), ["refresh", "cpuTemp"], "keeps the picked order")
assert.strictEqual(Model.barParts(barStatus, ["cpuTemp"])[0].temp, 77)
assert.strictEqual(Model.barParts(barStatus, ["fans"])[0].temp, null)
const asleep = Object.assign({}, barStatus, { ac: false, dgpu: "suspended", temps: { cpu: 50, gpu: null }, watts: { igpu: 12.4, dgpu: null } })
assert.deepStrictEqual(Model.barParts(asleep, ["gpuTemp", "dgpu", "power", "battery"]).map(p => p.text),
  ["󰢮 asleep", "󰻠 12 W", "󰁹 76%"], "no GPU temperature while it sleeps")
assert.strictEqual(new Set(Model.BAR_STATS.map(s => s.key)).size, Model.BAR_STATS.length)
const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, "..", "manifest.json"), "utf8"))
assert.deepStrictEqual(manifest.barWidget.schema.map(e => e.key), Model.BAR_STATS.map(s => s.key), "manifest offers every bar stat")
for (const entry of manifest.barWidget.schema) assert.strictEqual(manifest.barWidget.defaults[entry.key], entry.defaultValue, entry.key + " default agrees")

// Each mode has the glyph Omarchy's power menu gives it: leaf, gauge, speedometer.
assert.deepStrictEqual(Model.PROFILES.map(p => p.label), ["Silent", "Balanced", "Turbo"])
assert.deepStrictEqual(Model.PROFILES.map(p => p.icon.codePointAt(0)), [0xf032a, 0xf029a, 0xf04c5])

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

console.log("model tests passed")
