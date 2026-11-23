import QtQuick
import qs.Commons
import "../Model.js" as Model

// The GPU mode and what the NVIDIA GPU is doing, with its draw in the block
// face while it is awake (it is never woken to read it; its temperature is
// in the CPU and GPU room). Asleep or off, the figure is a dash. Its drawer
// (GraphicsDrawer) switches the mode.
Room {
  id: room

  readonly property var service: host.service
  readonly property var status: host.status
  readonly property var gpu: status ? status.gpu : null
  readonly property string next: gpu && service ? String(service.pick("gpu.next", gpu.next)) : ""
  readonly property var info: Model.gpuModeInfo(gpu ? gpu.mode : "")
  readonly property var draw: status && status.watts && status.dgpu === "active" ? status.watts.dgpu : null

  tone: host.toneOf("graphics")
  expanded: host.openRoom === "graphics"
  headerNatural: header.naturalHeight
  onClicked: host.toggleRoom("graphics")

  RoomHeader {
    id: header
    host: room.host
    minHeight: room.headerMin
    icon: "gpu"
    tone: room.tone
    title: room.gpu ? room.info.label : "Graphics"
    status: Model.graphicsState(room.gpu, room.status ? room.status.dgpu : "", null, room.next)
    value: room.draw
    suffix: "W"
    figureDimmed: room.draw === null || room.draw === undefined
    mark: room.gpu && room.next !== room.gpu.mode ? "reload" : ""
    expanded: room.expanded
    delay: room.delay + 120
    tick: room.story
    // A new mode, or the NVIDIA GPU waking or sleeping, turns its fans.
    cue: (room.gpu ? room.gpu.mode + room.next : "") + "/" + (room.status ? room.status.dgpu : "")
  }
}
