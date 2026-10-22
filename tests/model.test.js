// Run with: node tests/model.test.js
const fs = require("fs")
const path = require("path")
const assert = require("assert")

const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8").replace(/^\.pragma library\s*/, "")
const Model = new Function(source + "\nreturn { parseStatus, normalizeProfile, profileInfo, profileChoices, steppedProfile, heat, temperature, watts, rpm, maxFan, dgpuLabel, batteryLine, tooltip, defaultSettings, mergeSettings, cleanHex, auraEffects, nextAuraEffect, auraArgs, animeBuiltins, animeContent, refreshTarget, curveString, clampPoint, formatSeconds }")()

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

// fan curves
const pts = [{ t: 40, p: 10 }, { t: 50, p: 20 }, { t: 60, p: 30 }]
assert.strictEqual(Model.curveString(pts), "40:10,50:20,60:30")
assert.deepStrictEqual(Model.clampPoint(pts, 1, 70, 120), { t: 60, p: 100 }, "stays under the next point and 100 %")
assert.deepStrictEqual(Model.clampPoint(pts, 1, 30, -5), { t: 40, p: 0 })

console.log("model tests passed")
