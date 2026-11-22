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
  // An icon drawn in frames (the fan's two), flipped through to move it.
  property var frames: []
  property int spinEvery: 0
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
  property string story: "pop"
  property int tick: 0
  property real k: 1
  property int spinPhase: 0
  readonly property real figureSize: Style.font.caption - 2
  readonly property var pose: Rooms.storyPose(story, k)
  readonly property string shownIcon: frames.length > 1
    ? frames[(spinPhase + (story === "spin" ? Rooms.spinFrame(k) : 0)) % frames.length] : icon
  readonly property real gap: Style.space(7)
  // The group at its widest figure (100%), so the stack's width holds still
  // as the number changes.
  readonly property real naturalWidth: iconBox.width + gap + widest.implicitWidth

  width: parent ? parent.width : 0
  implicitHeight: Math.max(iconBox.height, figure.implicitHeight)

  onTickChanged: if (!Style.reduceMotion) storyRun.restart()

  NumberAnimation {
    id: storyRun
    target: head
    property: "k"
    from: 0
    to: 1
    duration: Style.duration(head.story === "spin" ? 900 : 660)
  }

  Timer {
    interval: Math.max(100, head.spinEvery)
    repeat: true
    running: head.spinEvery > 0 && head.host.opened && head.visible && !Style.reduceMotion && !storyRun.running
    onTriggered: head.spinPhase = (head.spinPhase + 1) % 2
  }

  Counter {
    id: count
    host: head.host
    value: head.value
    delay: head.delay
  }

  Row {
    anchors.centerIn: parent
    spacing: head.gap

    // Moves in whole pixels of its own grid, so it never smears.
    PixelIcon {
      id: iconBox
      anchors.verticalCenter: parent.verticalCenter
      name: head.shownIcon
      size: Style.font.heading
      color: head.dimmed ? head.host.dim : head.tone
      transform: Translate { x: head.pose.x * iconBox.cell; y: head.pose.y * iconBox.cell }
    }

    BigFigure {
      id: figure
      anchors.verticalCenter: parent.verticalCenter
      // Slides to a new reading rather than jumping to it.
      value: count.known ? count.shown : null
      text: head.formatted ? head.formatted.text : ""
      suffix: head.formatted ? head.formatted.suffix : head.suffix
      tone: head.tone
      foreground: head.host.fg
      mark: head.mark
      dimmed: head.dimmed
      fontFamily: head.host.fontFamily
      fontSize: head.figureSize
    }
  }

  BigFigure {
    id: widest
    visible: false
    value: 100
    suffix: "%"
    mark: "zap"
    fontFamily: head.host.fontFamily
    fontSize: head.figureSize
  }
}
