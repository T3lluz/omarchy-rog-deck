import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Section title in Omarchy's panel style (bold small caps, dimmed) with an
// icon in front and, on the right, either a value or a switch for the whole
// section.
Item {
  id: header

  property string icon: ""
  property string title: ""
  property string detail: ""
  property bool showSwitch: false
  property bool checked: false
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family

  signal toggled()

  width: parent ? parent.width : implicitWidth
  implicitHeight: Math.max(titleText.implicitHeight, toggle.visible ? toggle.implicitHeight : 0, detailText.implicitHeight)

  Text {
    id: iconText
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    visible: header.icon !== ""
    width: visible ? Style.space(20) : 0
    textFormat: Text.PlainText
    text: header.icon
    color: Qt.darker(header.foreground, 1.4)
    font.family: header.fontFamily
    font.pixelSize: Style.font.body
  }

  PanelSectionHeader {
    id: titleText
    anchors.left: iconText.right
    anchors.leftMargin: iconText.visible ? Style.space(4) : 0
    anchors.verticalCenter: parent.verticalCenter
    text: header.title
    foreground: header.foreground
    fontFamily: header.fontFamily
  }

  Text {
    id: detailText
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    visible: !header.showSwitch && header.detail !== ""
    textFormat: Text.PlainText
    text: header.detail
    color: Qt.darker(header.foreground, 1.15)
    font.family: header.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }

  ToggleSwitch {
    id: toggle
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    visible: header.showSwitch
    checked: header.checked
    foreground: header.foreground
    accent: header.accent
    onToggled: header.toggled()
  }
}
