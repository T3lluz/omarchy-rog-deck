import QtQuick
import qs.Commons
import "Rooms.js" as Rooms

// A small room's content, for the two tiles stacked beside the CPU and GPU:
// its icon on the left and its figure on the right, both centred, no name.
// The icon says what it is, the room's tooltip names it and says its state,
// and a click opens it like any room.
Item {
  id: head

  required property var host
  property string icon: ""
  // An icon drawn in frames (the fan's two), flipped through to move it.
  property var frames: []
  property int spinEvery: 0
  property color tone: host.fg
  property var value: null
  // Digits to draw in place of the rounded value (a fan's 4.3).
  property string figureText: ""
  property string suffix: "%"
  property string mark: ""
  property bool dimmed: false
  property string story: "pop"
  property int tick: 0
  property real k: 1
  property int spinPhase: 0
  readonly property var pose: Rooms.storyPose(story, k)
  readonly property string shownIcon: frames.length > 1
    ? frames[(spinPhase + (story === "spin" ? Rooms.spinFrame(k) : 0)) % frames.length] : icon
  // What the tile needs side by side, for the stack's width.
  readonly property real naturalWidth: iconBox.width + Style.space(8) + widest.implicitWidth

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

  // Moves in whole pixels of its own grid, so it never smears.
  PixelIcon {
    id: iconBox
    y: Math.round((head.height - height) / 2)
    name: head.shownIcon
    size: head.host.iconColumn
    color: head.dimmed ? head.host.dim : head.tone
    transform: Translate { x: head.pose.x * iconBox.cell; y: head.pose.y * iconBox.cell }
  }

  BigFigure {
    id: figure
    anchors.right: parent.right
    y: Math.round((head.height - implicitHeight) / 2)
    value: head.value
    text: head.figureText
    suffix: head.suffix
    tone: head.tone
    foreground: head.host.fg
    mark: head.mark
    dimmed: head.dimmed
    fontFamily: head.host.fontFamily
  }

  // The widest figure the tile shows (100%), measured so the tile never
  // narrows or widens as its number changes.
  BigFigure {
    id: widest
    visible: false
    value: 100
    suffix: "%"
    mark: "zap"
    fontFamily: head.host.fontFamily
  }
}
