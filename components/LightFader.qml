import QtQuick
import qs.Commons
import qs.Ui

// A light's level, the way Sonus lays out a fader: a button in the room's
// icon column that turns it off and back on, then the meter, a cell per
// level (Low, Med, High). A press anywhere in a cell picks that level. Off,
// the cells stay where they were, dimmed, so turning it back on returns to
// them.
Item {
  id: fader

  required property var host
  // The level, 1..segments, kept while the light is off.
  property int level: 0
  property bool on: level > 0
  property int segments: 3
  property color tone: host.fg
  property int delay: 0
  // What the button's tooltip calls the light.
  property string name: ""
  property var labels: ["Low", "Med", "High"]
  readonly property alias meter: bar

  signal picked(int level)
  signal toggled()

  width: parent ? parent.width : implicitWidth
  implicitHeight: Math.max(bar.implicitHeight, button.height)

  Item {
    id: button
    width: fader.host.iconColumn
    height: Math.max(bar.implicitHeight, icon.implicitHeight + Style.space(4))
    anchors.verticalCenter: parent.verticalCenter

    Rectangle {
      anchors.centerIn: parent
      width: parent.width + Style.space(4)
      height: parent.height + Style.space(2)
      radius: Style.cornerRadius
      visible: buttonMouse.containsMouse
      color: Qt.rgba(fader.tone.r, fader.tone.g, fader.tone.b, 0.16)
    }

    PixelIcon {
      id: icon
      x: Math.round((parent.width - width) / 2)
      y: Math.round((parent.height - height) / 2)
      name: fader.on ? "sun" : "power-off"
      size: Style.font.heading
      color: fader.on ? fader.tone : fader.host.dim
    }

    MouseArea {
      id: buttonMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: fader.toggled()
    }

    PanelToolTip {
      visible: buttonMouse.containsMouse
      text: (fader.on ? "Turn off " : "Turn on ") + fader.name
      fontFamily: fader.host.fontFamily
    }
  }

  Meter {
    id: bar
    host: fader.host
    anchors.left: button.right
    anchors.leftMargin: Style.space(10)
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    segments: fader.segments
    level: fader.level / fader.segments * 100
    tone: fader.tone
    foreground: fader.host.fg
    interactive: true
    perCell: true
    dimmed: !fader.on
    from: 0
    to: fader.segments
    step: 1
    delay: fader.delay
    tipText: fader.labels.join(", ")
    onCommitted: function(v) { fader.picked(Math.round(v)) }
  }
}
