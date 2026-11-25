import QtQuick
import qs.Commons
import "Rooms.js" as Rooms

// A small room's content, for the two tiles stacked beside the CPU and GPU:
// its icon and its figure side by side, centred in the tile as one group, no
// name. The icon says what it is, the room's tooltip names it and says its
// state, and a click opens it like any room. The figure is a size under the
// rooms' own, as the tile is.
Item {
  id: head

  required property var host
  property string icon: ""
  // A live state that keeps the icon moving (PixelIcon's `loop`), only while
  // the panel is open.
  property string loop: ""
  property int loopEvery: 0
  property color tone: host.fg
  property var value: null
  // Turns the number as drawn into digits and a unit, for a figure that is
  // not a whole number (a fan's 4.3k); null draws the rounded number.
  property var format: null
  property int delay: 0
  readonly property var formatted: typeof format === "function" && count.known ? format(count.shown) : null
  property string suffix: "%"
  property string mark: ""
  property bool dimmed: false
  // Plays the icon each time it goes up, and when the state it stands for
  // changes while the panel is open (RoomHeader's `tick` and `cue`).
  property int tick: 0
  property string cue: ""
  readonly property real figureSize: Style.font.caption - 2
  readonly property real gap: Style.space(7)
  // The group at its widest figure (100%), so the stack's width holds still
  // as the number changes.
  readonly property real naturalWidth: iconBox.width + gap + widest.implicitWidth

  width: parent ? parent.width : 0
  implicitHeight: Math.max(iconBox.height, figure.implicitHeight)

  onTickChanged: iconBox.play(0)
  onCueChanged: if (head.host.opened) iconBox.play(0)

  Counter {
    id: count
    host: head.host
    value: head.value
    delay: head.delay
  }

  Row {
    anchors.centerIn: parent
    spacing: head.gap

    PixelIcon {
      id: iconBox
      anchors.verticalCenter: parent.verticalCenter
      name: head.icon
      size: Style.font.heading
      color: head.dimmed ? head.host.dim : head.tone
      loop: head.host.opened ? head.loop : ""
      loopEvery: head.loopEvery
    }

    BigFigure {
      id: figure
      anchors.verticalCenter: parent.verticalCenter
      // Slides to a new reading rather than jumping to it.
      value: count.known ? count.shown : null
      text: head.formatted ? head.formatted.text : ""
      target: head.value
      targetText: typeof head.format === "function" && Rooms.hasLevel(head.value) ? head.format(head.value).text : ""
      suffix: head.formatted ? head.formatted.suffix : head.suffix
      tone: head.tone
      foreground: head.host.fg
      mark: head.mark
      dimmed: head.dimmed
      fontFamily: head.host.gridFamily
      fontSize: head.figureSize
    }
  }

  BigFigure {
    id: widest
    visible: false
    value: 100
    suffix: "%"
    mark: "zap"
    fontFamily: head.host.gridFamily
    fontSize: head.figureSize
  }
}
