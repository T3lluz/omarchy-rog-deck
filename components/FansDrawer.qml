import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// The fans room opened: the running mode's curve on or off, a preset for it
// in one click, the way into the curve itself, and the bar switch.
Column {
  id: drawer

  required property var host
  readonly property var service: host.service
  readonly property string mode: host.activeProfile
  readonly property var curves: service ? service.fanCurves : null
  readonly property var curve: curves ? curves[mode] : null
  readonly property bool custom: curve && service ? !!service.pick("fans." + mode, curve.custom) : false
  readonly property string modeName: Model.profileInfo(mode).label
  readonly property color tone: host.toneOf("fans")

  width: parent ? parent.width : 0
  spacing: Style.space(10)

  SwitchRow {
    width: parent.width
    visible: !!drawer.curve
    icon: ""
    label: "Custom curve in " + drawer.modeName
    hint: drawer.custom ? "Running now. Off hands the fans back to the firmware; your curve is kept"
                        : "Off: the firmware decides. Your curve is kept"
    checked: drawer.custom
    foreground: drawer.host.fg
    accent: drawer.tone
    fontFamily: drawer.host.fontFamily
    onToggled: drawer.service.setFanCustom(drawer.mode, !drawer.custom)
  }

  ChoiceRow {
    host: drawer.host
    visible: !!drawer.curve
    tone: drawer.tone
    compact: true
    options: Model.FAN_PRESETS.map(function(p) { return { value: p.value, label: p.label, pixel: p.pixel, hint: p.hint + ". Turns the custom curve on" } })
      .concat([{ value: "reset", label: "Reset", pixel: "undo", hint: "The firmware's curve, custom off" }])
    value: ""
    onPicked: function(v) {
      drawer.host.pickFans(drawer.mode, v, drawer.custom)
    }
  }

  Button {
    width: parent.width
    visible: !!drawer.curve
    text: "Edit the " + drawer.modeName + " curve"
    fontSize: Style.font.bodySmall
    foreground: drawer.host.fg
    fontFamily: drawer.host.fontFamily
    bordered: true
    onClicked: drawer.host.setView("fans")
  }

  Caption {
    width: parent.width
    visible: !drawer.curve
    text: drawer.curves ? "This laptop has no custom fan curves" : "Reading fan curves…"
    foreground: drawer.host.fg
    fontFamily: drawer.host.fontFamily
  }

  RoomPicks {
    host: drawer.host
    tone: drawer.tone
    stats: ["fans"]
  }
}
