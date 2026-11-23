import QtQuick
import qs.Commons

// A room's first line: its pixel icon, the name over a line of state, and
// the reading in the block face on the right. The chevron by the name says
// the room opens.
Item {
  id: head

  required property var host
  property string icon: ""
  // A live state that keeps the icon moving (PixelIcon's `loop`), only while
  // the panel is open.
  property string loop: ""
  property int loopEvery: 0
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
  // A count that plays the icon each time it goes up (the room coming in, a
  // click, the pointer arriving), and the state the icon stands for: a new
  // value plays it too, while the panel is open.
  property int tick: 0
  property string cue: ""
  readonly property alias iconItem: iconBox

  // A header beside a taller one in the same row stretches to match, its
  // own lines staying at the top, so the rooms' names and what sits under
  // the headers line up across the row.
  property real minHeight: 0
  readonly property real naturalHeight: Math.max(labels.implicitHeight, showFigure ? figure.implicitHeight : 0, iconBox.height)

  width: parent ? parent.width : 0
  implicitHeight: Math.max(minHeight, naturalHeight)

  onTickChanged: iconBox.play(0)
  onCueChanged: if (head.host.opened) iconBox.play(0)
  onExpandedChanged: chevron.play(0)

  PixelIcon {
    id: iconBox
    x: Math.round((head.host.iconColumn - width) / 2)
    y: Math.round((head.naturalHeight - height) / 2)
    name: head.icon
    size: head.host.iconColumn
    color: head.dimmed ? head.host.dim : head.tone
    loop: head.host.opened ? head.loop : ""
    loopEvery: head.loopEvery
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

      MonoText {
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
