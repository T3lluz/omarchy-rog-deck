import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "Model.js" as Model

// Headless half of ROG Deck. It stays loaded whether or not the bar widget
// is placed, owns the one status poller every panel reads from, runs actions
// through bin/rog-deck, and answers `omarchy-shell io.github.t3lluz.rog-deck …`.
Item {
  id: root

  // Injected by omarchy-shell.
  property var shell: null

  readonly property string pluginId: "io.github.t3lluz.rog-deck"
  readonly property string backend: String(Qt.resolvedUrl("bin/rog-deck")).replace(/^file:\/\//, "")

  property var status: null
  property string lastError: ""
  // Open panels and bar widgets that show live numbers. While any are
  // watching, sensors refresh every few seconds; otherwise rarely.
  property int watchers: 0
  property bool tookOver: false
  // A profile the user just picked, shown until the daemon reports it, so
  // the tiles don't flick back while the switch is in flight.
  property string pendingProfile: ""

  readonly property string activeProfile: pendingProfile
    || (status && status.profile ? String(status.profile.active || "") : "")

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function setProfile(name) {
    var key = Model.normalizeProfile(name)
    var known = Model.profileChoices(status).some(function(p) { return p.key === key })
    if (!known) return false
    if (key === activeProfile) return true
    pendingProfile = key
    pendingClear.restart()
    runAction(["profile", key])
    var info = Model.profileInfo(key)
    Quickshell.execDetached(["omarchy-osd", "-i", info.icon, "-m", info.label + " mode"])
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

  function withActive() {
    if (!status) return status
    var copy = JSON.parse(JSON.stringify(status))
    copy.profile.active = activeProfile
    return copy
  }

  function runAction(args) {
    // Actions are short; queue rather than drop one that arrives mid-run.
    actionQueue.push([root.backend].concat(args))
    pumpActions()
  }

  property var actionQueue: []
  function pumpActions() {
    if (actionProc.running || actionQueue.length === 0) return
    actionProc.command = actionQueue.shift()
    actionProc.running = true
  }

  function applyStatus(text) {
    var next = Model.parseStatus(text)
    if (!next) {
      lastError = "rog-deck status returned nothing"
      return
    }
    lastError = ""
    status = next
    if (pendingProfile && next.profile && next.profile.active === pendingProfile) pendingProfile = ""
    // Omarchy remembers a profile for AC and one for battery and applies it
    // on plug/unplug. asusd does the same from its own memory, so the two
    // race. Let Omarchy own it.
    if (!tookOver && next.profile && next.profile.asusdAutoSwitch) {
      tookOver = true
      runAction(["takeover"])
    }
  }

  Process {
    id: statusProc
    command: [root.backend, "status"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyStatus(text) }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: if (text.trim()) console.warn("rog-deck status: " + text.trim()) }
  }

  Process {
    id: actionProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim()) {
        root.lastError = text.trim()
        console.warn(root.lastError)
      }
    }
    onExited: function(code) {
      if (code !== 0) root.pendingProfile = ""
      root.refresh()
      root.pumpActions()
    }
  }

  Timer {
    interval: root.watchers > 0 ? 3000 : 20000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: pendingClear
    interval: 4000
    onTriggered: root.pendingProfile = ""
  }

  // Omarchy switches the profile when the charger changes; follow it.
  Connections {
    target: UPower
    function onOnBatteryChanged() { delayedRefresh.restart() }
  }

  Timer {
    id: delayedRefresh
    interval: 1500
    onTriggered: root.refresh()
  }

  IpcHandler {
    target: "io.github.t3lluz.rog-deck"

    function status(): string { return JSON.stringify(root.withActive()) }
    function refresh(): string { root.refresh(); return "ok" }
    function profile(name: string): string { return root.setProfile(name) ? "ok" : "unknown" }
    function nextProfile(): string { root.stepProfile(1); return "ok" }
    function prevProfile(): string { root.stepProfile(-1); return "ok" }
    function cycleProfile(): string { root.cycleProfile(); return "ok" }
    function toggle(): void { if (root.shell) root.shell.toggle(root.pluginId, "{}") }
    function open(): void { if (root.shell) root.shell.summon(root.pluginId, "{}") }
  }
}
