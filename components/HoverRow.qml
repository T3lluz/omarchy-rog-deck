import QtQuick
import qs.Commons
import "Rooms.js" as Rooms

// One line of the bar's hover card: a room tinted in its colour, as in the
// panel, with its pixel icon, its name (wrapping, never cut), the mark in a
// column every row keeps, a small meter of five cells for a reading that has
// a level (a temperature, the battery) and the figure in the pixel type,
// right-aligned so the figures line up.
Rectangle {
  id: hoverRow

  // { name, icon, level, figure, mark, dimmed } from Model.hoverRows.
  property var entry: ({})
  property color tone: "white"
  property color foreground: "white"
  property int unit: 2
  property string fontFamily: Style.font.family
  // How long after the card shows this row's icon plays, so they go down
  // the card one after another.
  property int delay: 0
  readonly property bool hasLevel: Rooms.hasLevel(hoverRow.entry.level)
  readonly property color quiet: Qt.darker(foreground, 1.5)

  height: Math.max(name.implicitHeight, Style.space(14)) + Style.space(6) * 2
  radius: Style.cornerRadius
  color: Qt.rgba(tone.r, tone.g, tone.b, 0.08)

  PixelIcon {
    id: icon
    x: Style.space(6)
    anchors.verticalCenter: parent.verticalCenter
    name: hoverRow.entry.icon || ""
    playOnShow: true
    showDelay: hoverRow.delay
    size: Style.font.body
    color: hoverRow.entry.dimmed ? hoverRow.quiet : hoverRow.tone
  }

  MonoText {
    id: name
    anchors.left: icon.right
    anchors.leftMargin: Style.space(6)
    anchors.right: markSlot.left
    anchors.rightMargin: Style.space(6)
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    text: hoverRow.entry.name || ""
    color: hoverRow.entry.dimmed ? hoverRow.quiet : hoverRow.foreground
    font.family: hoverRow.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  // The mark (charging, plugged in, hot) in a column of its own that is there
  // on every row, empty or not, so the meters and figures stay in one place.
  Item {
    id: markSlot
    anchors.right: cells.left
    anchors.rightMargin: Style.space(5)
    anchors.verticalCenter: parent.verticalCenter
    width: markIcon.implicitWidth
    height: markIcon.implicitHeight

    PixelIcon {
      id: markIcon
      visible: !!hoverRow.entry.mark
      name: hoverRow.entry.mark || "zap"
      playOnShow: true
      showDelay: hoverRow.delay + 120
      size: Style.font.body
      color: hoverRow.tone
    }
  }

  // Five cells, a fifth of the level each. Rows without a level keep the
  // space, so every figure sits in the same column.
  Item {
    id: cells
    anchors.right: level.left
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(54)
    height: Style.space(9)
    visible: hoverRow.hasLevel

    Rectangle {
      anchors.fill: parent
      color: "transparent"
      border.width: Math.max(1, Style.space(1))
      border.color: Qt.rgba(hoverRow.tone.r, hoverRow.tone.g, hoverRow.tone.b, 0.6)
    }

    Row {
      id: cellRow
      readonly property real stroke: Math.max(1, Style.space(1))
      readonly property real cellWidth: (width - spacing * 4) / 5
      readonly property real fill: hoverRow.hasLevel ? Math.max(0, Math.min(100, hoverRow.entry.level)) / 20 : 0
      x: stroke * 2
      y: stroke * 2
      width: parent.width - x * 2
      height: parent.height - y * 2
      spacing: stroke

      Repeater {
        model: 5

        Item {
          required property int index
          width: cellRow.cellWidth
          height: cellRow.height

          Rectangle {
            anchors.fill: parent
            color: Qt.rgba(hoverRow.tone.r, hoverRow.tone.g, hoverRow.tone.b, 0.12)
            antialiasing: false
          }

          Rectangle {
            width: parent.width * Math.max(0, Math.min(1, cellRow.fill - index))
            height: parent.height
            color: hoverRow.tone
            antialiasing: false
          }
        }
      }
    }
  }

  // The figure, right-aligned in a column as wide as "165Hz", so the figures
  // line up.
  Item {
    id: level
    anchors.right: parent.right
    anchors.rightMargin: Style.space(6)
    anchors.verticalCenter: parent.verticalCenter
    width: Rooms.pixelText("165Hz").width * figure.cell
    height: figure.implicitHeight

    PixelText {
      id: figure
      anchors.right: parent.right
      text: hoverRow.entry.figure || ""
      unit: hoverRow.unit
      color: hoverRow.entry.dimmed ? hoverRow.quiet : hoverRow.foreground
    }
  }
}
