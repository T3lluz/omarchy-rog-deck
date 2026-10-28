import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import "Model.js" as Model
import "components"

// Headless half of ROG Deck. It stays loaded whether or not the bar widget
// is placed: it owns the one status poller every panel reads from, runs
// actions through bin/rog-deck, keeps the settings file, and does the jobs
// that must happen with the panel closed: keyboard auto-off, putting FN-lock
// back after login, following the charger for the Auto refresh rate, and
// re-applying the keyboard effect after a theme change.
// It also answers `omarchy-shell io.github.t3lluz.rog-deck …`.
Item {
  id: root

  // Injected by omarchy-shell.
  property var shell: null

  readonly property string pluginId: "io.github.t3lluz.rog-deck"
  readonly property string backend: String(Qt.resolvedUrl("bin/rog-deck")).replace(/^file:\/\//, "")
  readonly property string home: Quickshell.env("HOME")
  readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/rog-deck"
  readonly property string settingsPath: configDir + "/settings.json"
  readonly property string themeColourPath: home + "/.local/state/omarchy/current/theme/keyboard.rgb"

  property var status: null
  property var fanCurves: null
  property string lastError: ""
  // Open panels and bar widgets that show live numbers. While any are
  // watching, sensors refresh every few seconds; otherwise rarely.
  property int watchers: 0
  property bool tookOver: false
  property bool startupDone: false
  // Values the user just set, shown until the next status read after the
  // action finishes, so controls don't flick back while it is in flight.
  property var optimistic: ({})

  property var settings: Model.defaultSettings()
  property bool settingsLoaded: false
  property string themeColour: ""
  // The panel tab last shown; shared so every monitor's panel agrees.
  property string panelTab: "main"
  // GPU mode waiting on the panel's restart prompt, or "".
  property string gpuAsk: ""

  // Updates go through bin/plugin-update, the same as Batteries' and Server
  // Dashboard's; the System tab's About section and the banner read it.
  readonly property alias updater: updaterItem
  // Banners the user closed, by key, with the text they had; a new text shows again.
  property var dismissed: ({})

  readonly property string activeProfile: String(pick("profile", status && status.profile ? status.profile.active || "" : ""))
  readonly property bool kbdIdleArmed: settingsLoaded && settings.kbdIdle.enabled && settings.kbdIdle.timeout > 0
    && !(settings.kbdIdle.keepOnAc && !UPower.onBattery)

  // ---------------------------------------------------------------- state

  function pick(key, actual) {
    return optimistic.hasOwnProperty(key) ? optimistic[key] : actual
  }

  function setOptimistic(key, value) {
    var next = Object.assign({}, optimistic)
    next[key] = value
    optimistic = next
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function refreshFans() {
    if (!fansProc.running) fansProc.running = true
  }

  function withActive() {
    if (!status) return status
    var copy = JSON.parse(JSON.stringify(status))
    copy.profile.active = activeProfile
    return copy
  }

  function applyStatus(text) {
    var next = Model.parseStatus(text)
    if (!next) {
      lastError = "rog-deck status returned nothing"
      return
    }
    status = next
    if (!actionProc.running && actionQueue.length === 0) optimistic = ({})
    // Omarchy remembers a profile for AC and one for battery and applies it
    // on plug/unplug. asusd does the same from its own memory, so the two
    // race. Let Omarchy own it.
    if (!tookOver && next.profile && next.profile.asusdAutoSwitch) {
      tookOver = true
      run(["takeover"])
    }
    if (!startupDone && settingsLoaded) startup()
    else if (startupDone) syncFromStatus()
  }

  // Once per shell start (so once per login): put back what asusd and keyd
  // don't keep themselves.
  function startup() {
    startupDone = true
    run(["kbd", "idle-on"])
    var fn = settings.fnlock
    if (status.fnlock && status.fnlock.available && fn && (fn === "on") !== status.fnlock.on)
      run(["fnlock", fn])
    // ROG Deck shows only the firmware animations. If an image from an
    // earlier version or another tool switched them off, bring them back.
    var a = status.anime
    if (a && a.enabled && !a.builtinsEnabled) {
      var b = Model.animeBuiltins(a)
      run(["anime", "builtins", b.boot, b.awake, b.sleep, b.shutdown])
    }
    applyRefreshMode()
  }

  // Keep the saved FN-lock choice in step with Shift+Esc.
  function syncFromStatus() {
    if (status.fnlock && status.fnlock.available && !actionProc.running && actionQueue.length === 0) {
      var now = status.fnlock.on ? "on" : "off"
      if (settings.fnlock !== now) saveSetting(["fnlock"], now)
    }
  }

  // ------------------------------------------------------------- settings

  function saveSetting(path, value) {
    var next = JSON.parse(JSON.stringify(settings))
    var node = next
    for (var i = 0; i < path.length - 1; i++) {
      if (typeof node[path[i]] !== "object" || node[path[i]] === null) node[path[i]] = {}
      node = node[path[i]]
    }
    node[path[path.length - 1]] = value
    settings = next
    settingsSave.restart()
  }

  function loadSettings(raw) {
    if (settingsLoaded) return
    settings = Model.mergeSettings(raw)
    settingsLoaded = true
    if (!startupDone && status) startup()
  }

  // ------------------------------------------------------------- actions

  function run(args) {
    // Actions are short; queue rather than drop one that arrives mid-run.
    actionQueue.push([root.backend].concat(args))
    pumpActions()
  }

  property var actionQueue: []
  property var currentAction: []
  function pumpActions() {
    if (actionProc.running || actionQueue.length === 0) return
    currentAction = actionQueue.shift()
    actionProc.command = currentAction
    actionProc.running = true
  }

  function setProfile(name) {
    var key = Model.normalizeProfile(name)
    var known = Model.profileChoices(status).some(function(p) { return p.key === key })
    if (!known) return false
    if (key === activeProfile) return true
    setOptimistic("profile", key)
    run(["profile", key])
    var info = Model.profileInfo(key)
    osd(info.icon, info.label + " mode")
    return true
  }

  function stepProfile(delta) {
    var next = Model.steppedProfile(withActive(), delta)
    if (next) setProfile(next)
  }

  // Wraps around at the ends, for the ROG fan key.
  function cycleProfile() {
    var choices = Model.profileChoices(status)
    if (choices.length === 0) return
    var index = 0
    for (var i = 0; i < choices.length; i++) if (choices[i].key === activeProfile) index = i
    setProfile(choices[(index + 1) % choices.length].key)
  }

  function osd(icon, message) {
    Quickshell.execDetached(["omarchy-osd", "-i", icon, "-m", message])
  }

  // Keyboard -------------------------------------------------------------

  function setKbdBrightness(level) {
    setOptimistic("kbd.brightness", level)
    run(["kbd", "brightness", String(level)])
  }

  function toggleKbd() {
    if (!status || !status.keyboard) return
    var level = pick("kbd.brightness", status.keyboard.brightness)
    if (level > 0) {
      saveSetting(["kbdLastLevel"], level)
      setKbdBrightness(0)
    } else {
      setKbdBrightness(settings.kbdLastLevel || 2)
    }
  }

  // One field of the lighting effect changed; save and apply the whole thing.
  function setLighting(field, value) {
    if (field) saveSetting(["kbdLight", field], value)
    saveSetting(["kbdLight", "managed"], true)
    // A setting that only changes how colours are picked has nothing to
    // send on a white-only keyboard.
    if (field === "rgb" || ((field === "followTheme" || field === "colour" || field === "colour2") && !settings.kbdLight.rgb)) return
    applyLighting()
  }

  function applyLighting() {
    var light = settings.kbdLight
    var args = Model.auraArgs(light, root.themeColour)
    if (!args) return
    setOptimistic("kbd.mode", Model.auraEffectId(light.effect))
    run(["aura"].concat(args))
  }

  function cycleAura() {
    var supported = status && status.keyboard ? status.keyboard.modes || [] : []
    var next = Model.nextAuraEffect(settings.kbdLight.effect, supported, settings.kbdLight.rgb)
    if (!next) return
    setLighting("effect", next)
    osd("󰌌", Model.auraEffectLabel(next))
  }

  function setLedPower(slot, on) {
    var power = status && status.keyboard && status.keyboard.power
      ? Object.assign({}, status.keyboard.power) : { boot: true, awake: true, sleep: true, shutdown: true }
    power[slot] = on
    setOptimistic("kbd.power." + slot, on)
    run(["aura-power", power.boot ? "1" : "0", power.awake ? "1" : "0", power.sleep ? "1" : "0", power.shutdown ? "1" : "0"])
  }

  function setKbdIdle(field, value) {
    saveSetting(["kbdIdle", field], value)
  }

  // AniMe ----------------------------------------------------------------

  function setAnimeEnabled(on) {
    setOptimistic("anime.enabled", on)
    run(["anime", on ? "on" : "off"])
  }

  function setAnimeBrightness(level) {
    setOptimistic("anime.brightness", level)
    run(["anime", "brightness", String(level)])
  }

  function setAnimeOption(option, on) {
    setOptimistic("anime.option." + option, on)
    run(["anime", "option", option, on ? "on" : "off"])
  }

  // What shows while awake: "banner" or "logo".
  function setAnimeContent(content) {
    var choice = Model.ANIME_CONTENT.filter(function(c) { return c.value === content })[0]
    if (!choice) return
    setOptimistic("anime.awake", choice.builtin)
    setAnimeBuiltin("awake", choice.builtin)
  }

  function setAnimeBuiltin(slot, name) {
    var b = Model.animeBuiltins(status ? status.anime : null, slot, name)
    setOptimistic("anime." + slot, name)
    run(["anime", "builtins", b.boot, b.awake, b.sleep, b.shutdown])
  }

  // Battery, firmware, display, FN-lock ---------------------------------

  function setChargeLimit(limit) {
    setOptimistic("battery.limit", limit)
    run(["battery", "limit", String(limit)])
  }

  function chargeOnce() {
    run(["battery", "oneshot"])
    osd("󰂄", "Charging to 100% once")
  }

  function setArmoury(name, value) {
    setOptimistic("armoury." + name, value)
    run(["armoury", name, String(value)])
  }

  function setRefreshMode(mode) {
    saveSetting(["refresh"], mode)
    applyRefreshMode()
  }

  function applyRefreshMode() {
    var target = Model.refreshTarget(settings.refresh, status ? status.display : null, !UPower.onBattery)
    if (!target || (status && status.display && status.display.refresh === target)) return
    setOptimistic("display.refresh", target)
    run(["refresh", String(target)])
  }

  function setFnlock(on) {
    saveSetting(["fnlock"], on ? "on" : "off")
    setOptimistic("fnlock", on)
    run(["fnlock", on ? "on" : "off"])
  }

  // GPU ------------------------------------------------------------------

  // Queue a GPU mode for the next boot. With `restart`, reboot once it is
  // queued; the panel asks before passing that.
  function setGpuMode(mode, restart) {
    setOptimistic("gpu.next", mode)
    run(["gpu", "set", mode].concat(restart ? ["--restart"] : []))
  }

  // A switch only takes hold on restart, so the panel asks first. Picking the
  // mode that is already running just cancels a pending switch.
  function askGpuMode(mode) {
    var gpu = status ? status.gpu : null
    if (!gpu || gpu.modes.indexOf(mode) === -1) return false
    if (mode === gpu.mode) setGpuMode(mode, false)
    else gpuAsk = mode
    return true
  }

  // Updates and banners --------------------------------------------------

  function checkUpdates() { updaterItem.checkNow() }
  function applyUpdate() { updaterItem.apply() }

  // The banners over every tab, most urgent first.
  readonly property var notices: {
    var list = []
    if (lastError) list.push({ key: "error", tone: "urgent", icon: "󰀦", text: lastError, dismissable: true })
    var gpu = status ? status.gpu : null
    var gpuNotice = Model.gpuNotice(gpu, gpu ? String(pick("gpu.next", gpu.next)) : "")
    if (gpuNotice) list.push(gpuNotice)
    if (updaterItem.notice) list.push(updaterItem.notice)
    return list.filter(function(n) { return dismissed[n.key] !== n.text })
  }

  function dismissNotice(notice) {
    if (notice.key === "error") {
      lastError = ""
      return
    }
    var next = Object.assign({}, dismissed)
    next[notice.key] = notice.text
    dismissed = next
  }

  // Fans -----------------------------------------------------------------

  function setFanCustom(mode, on) {
    setOptimistic("fans." + mode, on)
    run(["fans", "custom", mode, on ? "on" : "off"])
  }

  function setFanCurve(mode, fan, points) {
    run(["fans", "set", mode, fan, Model.curveString(points)])
  }

  function setFanPreset(mode, preset) {
    run(["fans", "preset", mode, preset])
  }

  function resetFans(mode) {
    run(["fans", "reset", mode])
  }

  // ------------------------------------------------------------ processes

  Process {
    id: statusProc
    command: [root.backend, "status"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyStatus(text) }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: if (text.trim()) console.warn("rog-deck status: " + text.trim()) }
  }

  Process {
    id: fansProc
    command: [root.backend, "fans"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var data = Model.parseStatus(text)
        if (data) root.fanCurves = data
      }
    }
  }

  Process {
    id: actionProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = text.trim()
        if (message) {
          root.lastError = message.replace(/^rog-deck: /, "")
          console.warn("rog-deck: " + message)
          errorClear.restart()
        }
      }
    }
    onExited: function(code) {
      if (code !== 0) root.optimistic = ({})
      if (root.currentAction[1] === "fans") root.refreshFans()
      root.refresh()
      root.pumpActions()
    }
  }

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", root.configDir]
    running: true
    onExited: settingsFile.reload()
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    blockLoading: false
    onLoaded: root.loadSettings(text())
    onLoadFailed: root.loadSettings("")
  }

  Timer {
    id: settingsSave
    interval: 300
    onTriggered: settingsFile.setText(JSON.stringify(root.settings, null, 2) + "\n")
  }

  // Omarchy's theme switcher sets the keyboard to the theme colour as a
  // static effect. Follow the new colour, and put a non-static effect back.
  FileView {
    id: themeColourFile
    path: root.themeColourPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      var colour = Model.cleanHex(text())
      var changed = root.themeColour !== "" && colour !== root.themeColour
      root.themeColour = colour
      if (changed && root.settings.kbdLight.managed) themeReapply.restart()
    }
    onFileChanged: reload()
  }

  Updater {
    id: updaterItem
    pluginDir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, "")
    autoCheck: root.settingsLoaded && root.settings.updates.autoCheck
  }

  Timer {
    id: themeReapply
    interval: 1500
    onTriggered: root.applyLighting()
  }

  Timer {
    id: errorClear
    interval: 15000
    onTriggered: root.lastError = ""
  }

  Timer {
    interval: root.watchers > 0 ? 3000 : 20000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Keyboard auto-off. Inhibitors (a playing video) are ignored on purpose:
  // they keep the screen awake, not the keyboard light.
  IdleMonitor {
    id: kbdIdle
    enabled: root.kbdIdleArmed
    timeout: Math.max(5, root.settings.kbdIdle.timeout)
    respectInhibitors: false
    onIsIdleChanged: {
      if (isIdle) root.run(["kbd", "idle-off", root.settings.kbdIdle.dimOnly ? "1" : "0"])
      else root.run(["kbd", "idle-on"])
    }
  }

  onKbdIdleArmedChanged: if (!kbdIdleArmed && startupDone) run(["kbd", "idle-on"])

  // Omarchy switches the profile when the charger changes; follow it, and
  // move the Auto refresh rate with it.
  Connections {
    target: UPower
    function onOnBatteryChanged() { chargerChanged.restart() }
  }

  Timer {
    id: chargerChanged
    interval: 1500
    onTriggered: {
      root.refresh()
      root.applyRefreshMode()
    }
  }

  IpcHandler {
    target: "io.github.t3lluz.rog-deck"

    function status(): string { return JSON.stringify(root.withActive()) }
    function refresh(): string { root.refresh(); return "ok" }
    function version(): string { return root.status && root.status.version ? root.status.version : "unknown" }
    function checkUpdates(): string { root.checkUpdates(); return "ok" }
    function update(): string {
      if (!updaterItem.available) return "up to date"
      root.applyUpdate()
      return "updating"
    }
    function profile(name: string): string { return root.setProfile(name) ? "ok" : "unknown" }
    function nextProfile(): string { root.stepProfile(1); return "ok" }
    function prevProfile(): string { root.stepProfile(-1); return "ok" }
    function cycleProfile(): string { root.cycleProfile(); return "ok" }
    function cycleAura(): string { root.cycleAura(); return "ok" }
    function toggleKeyboard(): string { root.toggleKbd(); return "ok" }
    function fnlock(state: string): string {
      if (state === "toggle") root.setFnlock(!(root.status && root.status.fnlock && root.status.fnlock.on))
      else if (state === "on" || state === "off") root.setFnlock(state === "on")
      else return "unknown"
      return "ok"
    }
    function anime(state: string): string {
      if (state === "toggle") root.setAnimeEnabled(!(root.status && root.status.anime && root.status.anime.enabled))
      else if (state === "on" || state === "off") root.setAnimeEnabled(state === "on")
      else return "unknown"
      return "ok"
    }
    function toggle(): void { if (root.shell) root.shell.toggle(root.pluginId, "{}") }
    function open(): void { if (root.shell) root.shell.summon(root.pluginId, "{}") }
    // Open the panel on one tab: main, lighting, anime, fans or system.
    function openTab(name: string): string {
      root.panelTab = name
      if (root.shell) root.shell.summon(root.pluginId, "{}")
      return "ok"
    }
    // Switch GPU mode: integrated, hybrid or dedicated. Opens the panel to
    // confirm the restart when one is needed.
    function gpu(mode: string): string {
      if (!root.askGpuMode(mode)) return "unknown"
      if (root.gpuAsk === "") return "ok"
      root.panelTab = "system"
      if (root.shell) root.shell.summon(root.pluginId, "{}")
      return "ok"
    }
  }
}
