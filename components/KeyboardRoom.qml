import QtQuick
import qs.Commons
import "../Model.js" as Model
import "Rooms.js" as Rooms

// The keyboard light: a button that turns it off and back on, then its level
// as three cells (Low, Med, High), each one click. Its drawer
// (KeyboardDrawer) holds auto-off and FN-lock.
Room {
  id: room

  readonly property var service: host.service
  readonly property var kb: host.status && host.status.keyboard ? host.status.keyboard : ({})
  readonly property int level: service ? service.pick("kbd.brightness", kb.brightness) || 0 : 0
  // Off, the cells keep the level it comes back to.
  readonly property int lastLevel: service ? Math.max(1, Math.min(3, service.settings.kbdLastLevel || 2)) : 2
  readonly property var idle: service ? service.settings.kbdIdle : ({ enabled: false })
  readonly property bool fnlockOn: !!(service && host.status && host.status.fnlock && host.status.fnlock.available
    && service.pick("fnlock", host.status.fnlock.on))

  tone: host.toneOf("keyboard")
  expanded: host.openRoom === "keyboard"
  headerNatural: header.naturalHeight
  cells: [fader.meter]
  onClicked: host.toggleRoom("keyboard")

  RoomHeader {
    id: header
    host: room.host
    minHeight: room.headerMin
    icon: "keyboard"
    tone: room.tone
    title: "Keyboard"
    status: Model.keyboardState(room.level, room.idle, room.fnlockOn)
    showFigure: false
    expanded: room.expanded
    delay: room.delay + 120
    story: Rooms.storyOf("keyboard")
    tick: room.story
  }

  LightFader {
    id: fader
    host: room.host
    tone: room.tone
    name: "the keyboard light"
    level: room.level > 0 ? room.level : room.lastLevel
    on: room.level > 0
    delay: room.delay + 80
    onPicked: function(v) { if (room.service) room.service.setKbdBrightness(v) }
    onToggled: if (room.service) room.service.toggleKbd()
  }
}
