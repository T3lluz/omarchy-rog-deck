import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// One choice in a list, drawn like the device rows in Omarchy's own panels:
// icon, name and a short description, filled when it is the current one.
CursorSurface {
  id: row

  property string icon: ""
  // Drawn in place of the `icon` glyph when set.
  property Component iconComponent: null
  property string title: ""
  property string subtitle: ""
  property string detail: ""
  property string fontFamily: Style.font.family
  // Set by a panel that walks rows with the keyboard.
  property bool keyboardCursor: false

  signal clicked()

  hasCursor: mouse.containsMouse || keyboardCursor
  implicitHeight: inner.implicitHeight + Style.spacing.xl

  Row {
    id: inner
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(8)
    anchors.rightMargin: Style.space(10)
    spacing: Style.space(10)

    Item {
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(22)
      height: Style.font.title

      Text {
        visible: !row.iconComponent
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: row.icon
        color: row.foreground
        font.family: row.fontFamily
        font.pixelSize: Style.font.title
      }

      Loader {
        anchors.centerIn: parent
        sourceComponent: row.iconComponent
      }
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - Style.space(22) - parent.spacing * 2 - detailText.width
      spacing: Style.space(1)

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: row.title
        color: row.foreground
        elide: Text.ElideRight
        font.family: row.fontFamily
        font.pixelSize: Style.font.body
        font.bold: row.current
      }

      Text {
        width: parent.width
        visible: row.subtitle !== ""
        textFormat: Text.PlainText
        text: row.subtitle
        color: row.foreground
        opacity: 0.55
        elide: Text.ElideRight
        font.family: row.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Text {
      id: detailText
      anchors.verticalCenter: parent.verticalCenter
      width: row.detail !== "" ? implicitWidth : 0
      textFormat: Text.PlainText
      text: row.detail
      color: row.foreground
      opacity: 0.7
      font.family: row.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: row.clicked()
  }
}
