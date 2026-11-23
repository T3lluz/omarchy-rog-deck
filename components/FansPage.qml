import QtQuick
import qs.Commons
import qs.Ui

// The fan curves, a page of their own off the fans room: the hero with a way
// back, then each mode's curve to pick, switch on and drag (FanCurves.qml).
Column {
  id: page

  required property var host

  spacing: Style.space(12)

  onVisibleChanged: if (visible && host.service) host.service.refreshFans()

  HeroBlock {
    width: parent.width
    host: page.host
    icon: "fan"
    iconColor: page.host.toneOf("fans")
    markSize: Math.round(Style.font.title * 1.5)
    title: "Fan curves"
    line: "Each mode keeps a curve of its own"
    keepLines: 1

    PixelButton {
      icon: "arrow-left"
      nudge: Math.round(page.host.gearTurn * 2)
      tooltipText: "Back to the rooms (esc)"
      foreground: page.host.fg
      fontFamily: page.host.fontFamily
      onClicked: page.host.setView("rooms")
    }
  }

  PanelSeparator { foreground: page.host.fg }

  FanCurves {
    width: parent.width
    deck: page.host
  }
}
