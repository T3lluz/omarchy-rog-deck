import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// One-line label (and optional hint) with a switch at the end. Lighter
// than qs.Ui Toggle, so a tab can stack several.
Item {
  id: row

  property string label: ""
  property string hint: ""
  property bool checked: false
  property bool busy: false
  property bool interactive: true
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family

  signal toggled()

  implicitHeight: Math.max(toggle.implicitHeight, labels.implicitHeight)
  opacity: interactive ? 1 : 0.45

  Column {
    id: labels
    anchors.left: parent.left
    anchors.right: toggle.left
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(1)

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: row.label
      color: row.foreground
      elide: Text.ElideRight
      font.family: row.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Text {
      width: parent.width
      visible: row.hint !== ""
      textFormat: Text.PlainText
      text: row.hint
      color: row.foreground
      opacity: 0.55
      wrapMode: Text.Wrap
      font.family: row.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  MouseArea {
    anchors.fill: labels
    enabled: row.interactive && !row.busy
    cursorShape: Qt.PointingHandCursor
    onClicked: row.toggled()
  }

  ToggleSwitch {
    id: toggle
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    checked: row.checked
    busy: row.busy
    interactive: row.interactive
    foreground: row.foreground
    accent: row.accent
    onToggled: row.toggled()
  }
}
