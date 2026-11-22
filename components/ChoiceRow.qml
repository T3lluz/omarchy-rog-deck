import QtQuick
import qs.Commons
import qs.Ui

// A pick of one, as small rooms in a row inside a room: each a pixel icon and
// a name in the room's tone, the one in use tinted deeper and outlined, as
// Sonus outlines an app's channel. Every cell is as wide as the others and as
// tall as the tallest name. `options` are { value, label, pixel, hint }.
Row {
  id: choices

  required property var host
  property var options: []
  property string value: ""
  property color tone: host.fg
  // The keyboard's cursor, an index, or -1.
  property int keyed: -1
  property bool compact: false

  signal picked(string value)

  width: parent ? parent.width : 0
  spacing: Style.space(3)

  readonly property real cellWidth: options.length > 0 ? (width - spacing * (options.length - 1)) / options.length : 0
  readonly property real rowHeight: {
    var h = 0
    for (var i = 0; i < children.length; i++) if (children[i].naturalHeight !== undefined) h = Math.max(h, children[i].naturalHeight)
    return h
  }

  Repeater {
    model: choices.options

    Rectangle {
      id: cell
      required property var modelData
      required property int index
      readonly property bool current: choices.value === String(modelData.value)
      readonly property bool hot: area.containsMouse
      readonly property real naturalHeight: content.implicitHeight + Style.space(choices.compact ? 5 : 7) * 2

      width: choices.cellWidth
      height: Math.max(naturalHeight, choices.rowHeight)
      radius: Style.cornerRadius
      color: Qt.rgba(choices.tone.r, choices.tone.g, choices.tone.b, current ? 0.2 : hot ? 0.13 : 0.075)
      border.width: current || choices.keyed === index ? Math.max(1, Style.space(1)) : 0
      border.color: Qt.rgba(choices.tone.r, choices.tone.g, choices.tone.b, current ? 0.75 : 0.5)

      Behavior on color { ColorAnimation { duration: Style.duration(140) } }

      Row {
        id: content
        anchors.centerIn: parent
        width: Math.min(implicitWidth, cell.width - Style.space(8))
        spacing: Style.space(6)

        PixelIcon {
          id: cellIcon
          visible: !!cell.modelData.pixel
          anchors.verticalCenter: parent.verticalCenter
          name: cell.modelData.pixel || ""
          size: Style.font.body
          color: cell.current ? choices.tone : Qt.rgba(choices.tone.r, choices.tone.g, choices.tone.b, 0.8)
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(implicitWidth, cell.width - Style.space(8) - (cellIcon.visible ? cellIcon.width + content.spacing : 0))
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
          text: cell.modelData.label
          color: cell.current ? choices.host.fg : choices.host.dim
          font.family: choices.host.fontFamily
          font.pixelSize: choices.compact ? Style.font.caption : Style.font.bodySmall
          font.bold: cell.current
        }
      }

      MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: choices.picked(String(cell.modelData.value))
      }

      PanelToolTip {
        visible: area.containsMouse && !!cell.modelData.hint
        text: cell.modelData.hint || ""
        fontFamily: choices.host.fontFamily
      }
    }
  }
}
