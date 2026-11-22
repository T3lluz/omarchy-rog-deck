import QtQuick
import qs.Commons
import "../Model.js" as Model
import "Rooms.js" as Rooms

// The fans, a tile stacked beside the CPU and GPU: the fan icon turning
// while they spin (faster for faster fans, still when they stop) and the
// faster fan's speed in the block face (4.3k). Each part's own fan is under
// its figure in the CPU and GPU room. Its tooltip names it and the curve in
// use; its drawer (FansDrawer) holds the curve: on or off, presets, the
// editor.
Room {
  id: room

  readonly property var service: host.service
  readonly property var status: host.status
  readonly property var curves: service ? service.fanCurves : null
  readonly property var curve: curves ? curves[host.activeProfile] : null
  readonly property bool custom: curve && service ? !!service.pick("fans." + host.activeProfile, curve.custom) : false
  readonly property var fastest: Model.maxFan(status)
  readonly property real naturalWidth: tile.naturalWidth + pad * 2
  // A tile is a size under a room: tighter round its small figure.
  pad: Style.space(7)

  tone: host.toneOf("fans")
  expanded: host.openRoom === "fans"
  tip: "Fans · " + Model.fansLine(fastest, false, true) + " · " + Model.fansState(custom, !!curve).toLowerCase()
  onClicked: host.toggleRoom("fans")

  TileHeader {
    id: tile
    host: room.host
    height: Math.max(implicitHeight, room.height - room.pad * 2)
    icon: "fan"
    frames: ["fan", "fan-2"]
    spinEvery: Rooms.spinInterval(room.fastest)
    value: room.fastest
    format: function(v) { return Model.fanFigure(Math.round(v)) }
    delay: room.delay + 80
    tone: room.tone
    story: Rooms.storyOf("fans")
    tick: room.story
  }
}
