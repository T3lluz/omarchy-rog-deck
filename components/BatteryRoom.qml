import QtQuick
import qs.Commons
import "../Model.js" as Model
import "Rooms.js" as Rooms

// The battery, a tile stacked beside the CPU and GPU: Batteries has the
// full story, so this keeps to the level and its mark (a bolt while
// charging, a plug while holding, the low battery when low). Its tooltip
// says what the charger is doing; its drawer (BatteryDrawer) is where ROG
// Deck's own battery controls live: the charge limit and Battery saver.
Room {
  id: room

  readonly property var service: host.service
  readonly property var status: host.status
  readonly property var battery: status ? status.battery : null
  readonly property var info: Model.batteryRoom(battery, !!status && status.ac, !!service && service.saverActive)
  readonly property bool low: info.mark === "battery-low"
  readonly property real naturalWidth: tile.naturalWidth + pad * 2

  tone: host.toneOf("battery")
  expanded: host.openRoom === "battery"
  tip: "Battery · " + info.state
  onClicked: host.toggleRoom("battery")

  TileHeader {
    id: tile
    host: room.host
    height: Math.max(implicitHeight, room.height - room.pad * 2)
    icon: Model.batteryPixel(room.battery ? room.battery.percent : null)
    tone: room.low ? room.host.lowTone : room.tone
    value: room.info.level
    suffix: "%"
    delay: room.delay + 80
    mark: room.info.mark
    story: Rooms.storyOf("battery")
    tick: room.story
  }
}
