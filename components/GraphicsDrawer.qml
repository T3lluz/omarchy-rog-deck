import QtQuick
import qs.Commons
import "../Model.js" as Model

// The graphics room opened: the GPU modes this laptop has, one click each
// (a switch restarts the laptop, after a prompt), and the bar switches.
Column {
  id: drawer

  required property var host
  readonly property var service: host.service
  readonly property var status: host.status
  readonly property var gpu: status && status.gpu ? status.gpu : null
  readonly property string next: gpu && service ? String(service.pick("gpu.next", gpu.next)) : ""
  readonly property bool pending: !!gpu && next !== gpu.mode
  readonly property color tone: host.toneOf("graphics")

  width: parent ? parent.width : 0
  spacing: Style.space(10)

  ChoiceRow {
    host: drawer.host
    visible: !!drawer.gpu
    tone: drawer.tone
    options: Model.gpuModes(drawer.gpu).map(function(m) { return { value: m.value, label: m.label, pixel: m.pixel, hint: m.hint } })
    value: drawer.next
    onPicked: function(v) { drawer.host.askGpuMode(v) }
  }

  Caption {
    width: parent.width
    visible: !!drawer.gpu
    text: {
      if (!drawer.gpu) return ""
      if (drawer.pending) return "Starts in " + Model.gpuModeInfo(drawer.next).label + " mode after the next restart. Pick " + Model.gpuModeInfo(drawer.gpu.mode).label + " to cancel."
      var line = Model.gpuModeInfo(drawer.next).hint + ". Switching restarts the laptop."
      if (drawer.gpu.needsSetup && drawer.gpu.modes.indexOf("integrated") !== -1)
        line += " Integrated installs supergfxctl the first time, which asks for your password."
      return line
    }
    foreground: drawer.host.fg
    fontFamily: drawer.host.fontFamily
  }

  RoomPicks {
    host: drawer.host
    tone: drawer.tone
    stats: ["dgpu", "gpuTemp"]
  }
}
