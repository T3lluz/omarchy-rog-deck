// Run with: node tests/model.test.js
const fs = require("fs")
const path = require("path")
const assert = require("assert")

const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8").replace(/^\.pragma library\s*/, "")
const Model = new Function(source + "\nreturn { parseStatus, normalizeProfile, profileInfo, profileChoices, steppedProfile, heat, temperature, watts, rpm, maxFan, dgpuLabel, batteryLine, tooltip }")()

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

console.log("model tests passed")
