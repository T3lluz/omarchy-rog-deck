import QtQuick
import qs.Commons
import "Rooms.js" as Rooms

// A room's first line: its pixel icon, the name over a line of state, and
// the reading in the block face on the right. The chevron by the name says
// the room opens.
Item {
  id: head

  required property var host
  property string icon: ""
  // An icon drawn in frames (the fan's two), flipped through to move it
  // without turning pixel art off the quarter turns.
  property var frames: []
  // While the panel is open, flip a frame this often (ms); 0 holds still.
  property int spinEvery: 0
  property color tone: host.fg
  // The figure's colour, where it differs from the icon's (hot, low).
  property color figureTone: tone
  property string title: ""
  property string status: ""
  property bool showFigure: true
  property var value: null
  property string suffix: "%"
  property string mark: ""
  property bool figureDimmed: false
  property bool showChevron: true
  property bool expanded: false
  property bool dimmed: false
  property int delay: 0
  // The icon's story (Rooms.storyOf) and a count that plays it each time it
  // goes up.
  property string story: "pop"
  property int tick: 0
  property real k: 1
  property int spinPhase: 0
  readonly property var pose: Rooms.storyPose(story, k)
  readonly property string shownIcon: frames.length > 1
    ? frames[(spinPhase + (story === "spin" ? Rooms.spinFrame(k) : 0)) % frames.length] : icon
  readonly property alias iconItem: iconBox

  // A header beside a taller one in the same row stretches to match, its
  // own lines staying at the top, so the rooms' names and what sits under
  // the headers line up across the row.
  property real minHeight: 0
  readonly property real naturalHeight: Math.max(labels.implicitHeight, showFigure ? figure.implicitHeight : 0, iconBox.height)

  width: parent ? parent.width : 0
  implicitHeight: Math.max(minHeight, naturalHeight)

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
    x: Math.round((head.host.iconColumn - width) / 2)
    y: Math.round((head.naturalHeight - height) / 2)
    name: head.shownIcon
    size: head.host.iconColumn
    color: head.dimmed ? head.host.dim : head.tone
    transform: Translate { x: head.pose.x * iconBox.cell; y: head.pose.y * iconBox.cell }
  }

  Column {
    id: labels
    anchors.left: parent.left
    anchors.leftMargin: head.host.textInset
    anchors.right: head.showFigure ? figure.left : parent.right
    anchors.rightMargin: head.showFigure ? Style.space(8) : 0
    y: Math.round((head.naturalHeight - implicitHeight) / 2)
    spacing: Style.space(1)

    // The name, wrapping when it must, with the chevron after its last line.
    Item {
      width: parent.width
      height: titleText.height

      Text {
        id: titleText
        readonly property real room: chevron.visible ? chevron.width + Style.space(5) : 0
        property real lastRight: 0
        property real lastY: 0
        property real lastHeight: 0
        width: Math.min(implicitWidth, parent.width - room)
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        text: head.title
        color: head.dimmed ? head.host.dim : head.host.fg
        font.family: head.host.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        onLineLaidOut: function(line) {
          if (!line.isLast) return
          lastRight = line.x + line.implicitWidth
          lastY = line.y
          lastHeight = line.height
        }
      }

      // Flips when the room opens; turned pixel art would smear on the way.
      PixelIcon {
        id: chevron
        visible: head.showChevron
        x: Math.round(titleText.lastRight + Style.space(5))
        y: Math.round(titleText.lastY + (titleText.lastHeight - height) / 2)
        name: "chevron-down"
        size: Style.font.caption
        color: head.host.dim
        rotation: head.expanded ? 180 : 0
      }
    }

    Decode {
      host: head.host
      width: parent.width
      visible: value !== ""
      wrapMode: Text.Wrap
      value: head.status
      delay: head.delay
      color: head.host.dim
      font.family: head.host.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Counter {
    id: count
    host: head.host
    value: head.showFigure ? head.value : null
    delay: head.delay
  }

  BigFigure {
    id: figure
    visible: head.showFigure
    anchors.right: parent.right
    y: Math.round((head.naturalHeight - implicitHeight) / 2)
    // Slides to a new reading rather than jumping to it.
    value: count.known ? count.shown : null
    suffix: head.suffix
    tone: head.figureTone
    foreground: head.host.fg
    mark: head.mark
    dimmed: head.figureDimmed
    fontFamily: head.host.gridFamily
  }
}
