import QtQuick
import qs.Commons
import "../Model.js" as Model

// The keyboard room opened: auto-off and how long it waits, whether the
// charger keeps it lit or it only dims, and FN-lock. Lighting at startup,
// sleep and shutdown, and the RGB effects, are on the settings page.
Column {
  id: drawer

  required property var host
  readonly property var service: host.service
  readonly property var status: host.status
  readonly property var idle: service ? service.settings.kbdIdle : Model.defaultSettings().kbdIdle
  readonly property bool fnlockAvailable: !!(status && status.fnlock && status.fnlock.available)
  readonly property color tone: host.toneOf("keyboard")

  width: parent ? parent.width : 0
  spacing: Style.space(10)

  SwitchRow {
    width: parent.width
    icon: ""
    label: "Turn off when idle"
    hint: drawer.idle.enabled
      ? "Goes dark after " + Model.formatSeconds(drawer.idle.timeout) + " without typing or touchpad, back on the next key press"
      : "The light stays as you set it"
    checked: drawer.idle.enabled
    foreground: drawer.host.fg
    accent: drawer.tone
    fontFamily: drawer.host.fontFamily
    onToggled: drawer.service.setKbdIdle("enabled", !drawer.idle.enabled)
  }

  ChoiceRow {
    host: drawer.host
    visible: drawer.idle.enabled
    tone: drawer.tone
    compact: true
    options: Model.IDLE_TIMEOUTS.map(function(t) { return { value: String(t.value), label: t.label } })
    value: String(drawer.idle.timeout)
    onPicked: function(v) { drawer.service.setKbdIdle("timeout", Number(v)) }
  }

  SwitchRow {
    width: parent.width
    visible: drawer.idle.enabled
    icon: ""
    label: "Stay on while plugged in"
    checked: drawer.idle.keepOnAc
    foreground: drawer.host.fg
    accent: drawer.tone
    fontFamily: drawer.host.fontFamily
    onToggled: drawer.service.setKbdIdle("keepOnAc", !drawer.idle.keepOnAc)
  }

  SwitchRow {
    width: parent.width
    visible: drawer.idle.enabled
    icon: ""
    label: "Dim instead of turning off"
    hint: "Drops to Low rather than dark"
    checked: drawer.idle.dimOnly
    foreground: drawer.host.fg
    accent: drawer.tone
    fontFamily: drawer.host.fontFamily
    onToggled: drawer.service.setKbdIdle("dimOnly", !drawer.idle.dimOnly)
  }

  SwitchRow {
    width: parent.width
    interactive: drawer.fnlockAvailable
    icon: ""
    label: "FN-lock"
    hint: drawer.fnlockAvailable ? "The top row does its printed media actions; hold Fn for F1 to F12. Shift+Esc toggles it too"
                                 : "Not set up: needs the fnlock command (see the README)"
    checked: drawer.fnlockAvailable && drawer.service ? !!drawer.service.pick("fnlock", drawer.status.fnlock.on) : false
    foreground: drawer.host.fg
    accent: drawer.tone
    fontFamily: drawer.host.fontFamily
    onToggled: drawer.service.setFnlock(!checked)
  }
}
