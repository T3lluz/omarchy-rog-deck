import QtQuick
import qs.Commons

// What an open room adds when it shares its row with another: a room the
// whole width of the row, in the open room's tone, sliding open under the
// pair, so its switches never squeeze into half a row. One drawer per row;
// it keeps showing what it held while it closes, so it never empties on the
// way out. Its gap above is part of its height, so closing ends without a
// snap.
Item {
  id: pair

  required property var host
  // The rooms of the row this drawer serves.
  property var keys: []
  readonly property string openKey: keys.indexOf(host.openRoom) !== -1 ? host.openRoom : ""
  property string shownKey: ""
  default property alias content: drawerColumn.data

  onOpenKeyChanged: if (openKey !== "") shownKey = openKey

  width: parent ? parent.width : 0
  height: openKey !== "" ? drawerRoom.implicitHeight + host.roomGap : 0
  visible: height > 0.5
  opacity: openKey !== "" ? 1 : 0
  clip: true

  Behavior on height { NumberAnimation { duration: Style.duration(pair.openKey !== "" ? 280 : 200); easing.type: Easing.OutCubic } }
  Behavior on opacity { NumberAnimation { duration: Style.duration(pair.openKey !== "" ? 220 : 160); easing.type: Easing.OutCubic } }

  Room {
    id: drawerRoom
    y: pair.host.roomGap
    host: pair.host
    tone: pair.host.toneOf(pair.shownKey)
    clickable: false
    expanded: true

    Column {
      id: drawerColumn
      width: parent.width
      spacing: Style.space(10)
    }
  }
}
