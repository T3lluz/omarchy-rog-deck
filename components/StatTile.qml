import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A small reading card: icon and caption, a big value, an optional note.
BorderSurface {
  id: tile

  property string icon: ""
  property string caption: ""
  property string value: "—"
  property string note: ""
  property color foreground: Commons.Color.foreground
  property color valueColor: foreground
  property string fontFamily: Style.font.family

  radius: Style.cornerRadius
  color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.04)
  borderSpec: Border.controlSpec("normal", foreground, Commons.Color.accent)
  implicitHeight: content.implicitHeight + Style.space(18)

  Column {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(10)
    anchors.rightMargin: Style.space(10)
    spacing: Style.space(2)

    Row {
      spacing: Style.space(6)

      Text {
        textFormat: Text.PlainText
        text: tile.icon
        color: tile.foreground
        opacity: 0.6
        font.family: tile.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        textFormat: Text.PlainText
        text: tile.caption
        color: tile.foreground
        opacity: 0.6
        font.family: tile.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 0.8
      }
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: tile.value
      color: tile.valueColor
      elide: Text.ElideRight
      font.family: tile.fontFamily
      font.pixelSize: Style.font.heading
      font.bold: true
      Behavior on color { ColorAnimation { duration: 300 } }
    }

    Text {
      width: parent.width
      visible: tile.note !== ""
      textFormat: Text.PlainText
      text: tile.note
      color: tile.foreground
      opacity: 0.55
      elide: Text.ElideRight
      font.family: tile.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
