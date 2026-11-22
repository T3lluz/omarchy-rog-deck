import QtQuick
import qs.Commons
import "../Model.js" as Model

// The CPU and GPU room opened: both readings in words, what the chips draw,
// and the bar switches for their temperatures.
Column {
  id: drawer

  required property var host
  readonly property var status: host.status
  readonly property color tone: host.toneOf("heat")

  width: parent ? parent.width : 0
  spacing: Style.space(10)

  Facts {
    host: drawer.host
    facts: {
      var list = Model.fanFacts(drawer.status)
      var w = drawer.status && drawer.status.watts ? drawer.status.watts : {}
      if (w.igpu !== null && w.igpu !== undefined) list.push({ label: "CPU and iGPU", value: Model.watts(w.igpu) })
      if (drawer.status && drawer.status.dgpu === "active" && w.dgpu) list.push({ label: "NVIDIA", value: Model.watts(w.dgpu) })
      return list
    }
  }

  Caption {
    width: parent.width
    text: "Warm from 70 °C, hot from 85 °C. The GPU is read only while it is awake, so checking never wakes it."
    foreground: drawer.host.fg
    fontFamily: drawer.host.fontFamily
  }

  RoomPicks {
    host: drawer.host
    tone: drawer.tone
    stats: ["cpuTemp", "gpuTemp"]
  }
}
