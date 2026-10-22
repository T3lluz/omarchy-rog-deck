import QtQuick
import qs.Commons
import qs.Commons as Commons

// Small caps heading inside a tab, quieter than PanelSectionHeader.
Text {
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  textFormat: Text.PlainText
  color: foreground
  opacity: 0.6
  font.family: fontFamily
  font.pixelSize: Style.font.caption
  font.bold: true
  font.letterSpacing: 1.2
}
