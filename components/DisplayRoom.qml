import QtQuick
import qs.Commons
import "../Model.js" as Model
import "Rooms.js" as Rooms

// The laptop's screen: its refresh rate in the block face and how the rate
// is chosen. Its drawer (DisplayDrawer) picks the rate and the panel's own
// switches.
Room {
  id: room

  readonly property var service: host.service
  readonly property var display: host.status ? host.status.display : null
  readonly property var rate: display && service ? service.pick("display.refresh", display.refresh) : null

  tone: host.toneOf("display")
  headerNatural: header.naturalHeight
  expanded: host.openRoom === "display"
  onClicked: host.toggleRoom("display")

  RoomHeader {
    id: header
    host: room.host
    minHeight: room.headerMin
    icon: "monitor"
    tone: room.tone
    title: "Display"
    status: Model.displayState(room.service ? room.service.settings.refresh : null, !!room.service && room.service.saverActive,
                               !!room.service && !room.service.onBattery)
    value: room.rate
    suffix: "Hz"
    expanded: room.expanded
    delay: room.delay + 120
    story: Rooms.storyOf("display")
    tick: room.story
  }
}
