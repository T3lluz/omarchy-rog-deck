import QtQuick
import qs.Commons
import "Rooms.js" as Rooms

// A page's title: the mark, a bold title, and the prompt line under it, typed
// out a character at a time behind a cursor. The prompt keeps room for two
// lines, so one wrapping as it changes moves nothing. On the rooms page it
// fills the first room.
Item {
  id: hero

  required property var host
  property string icon: "fire"
  property color iconColor: host.fg
  property real markSize: Style.font.display
  property string title: ""
  property string line: ""
  property color lineColor: Qt.darker(host.fg, 1.3)
  // A line that answers the pointer shows at once.
  property bool instant: false
  // Lines the prompt always keeps room for, so one wrapping as it changes
  // moves nothing. The rooms page keeps its lines short enough for one.
  property int keepLines: 2
  // Which line this is, apart from its numbers. A new key types the line
  // out; the same line with a new reading in it ("CPU at 95°") just swaps,
  // so a refresh never retypes the prompt. Empty: any change types.
  property string lineKey: ""
  property string typedKey: ""
  property int typedLength: 0
  default property alias actions: actionRow.children

  property int typed: 0
  property bool cursorOn: true
  readonly property string revealed: Rooms.revealLine(line, typed, cursorOn)

  implicitHeight: Math.max(mark.height, labels.implicitHeight)

  function arrive() {
    typedKey = lineKey
    typedLength = line.length
    typed = Style.reduceMotion ? line.length : 0
    mark.play(0)
  }

  onLineChanged: Qt.callLater(hero.retype)
  onLineKeyChanged: Qt.callLater(hero.retype)

  function retype() {
    var same = lineKey !== "" && lineKey === typedKey
    var done = typed >= typedLength
    typedKey = lineKey
    typedLength = line.length
    if (instant || Style.reduceMotion) typed = line.length
    else if (same) typed = done ? line.length : Math.min(typed, line.length)
    else typed = 0
  }
  onInstantChanged: if (instant) typed = line.length
  // A page coming into view types its line out and plays its mark again.
  onVisibleChanged: if (visible && host.opened) arrive()

  Connections {
    target: hero.host
    function onEntryChanged() { hero.arrive() }
  }

  Timer {
    interval: 22
    repeat: true
    running: hero.visible && hero.host.opened && hero.typed < hero.line.length
    onTriggered: hero.typed = Math.min(hero.line.length, hero.typed + 1)
  }

  Timer {
    interval: 530
    repeat: true
    running: hero.visible && hero.host.opened && !Style.reduceMotion
    onTriggered: hero.cursorOn = !hero.cursorOn
  }

  // Measures two real lines of the prompt, for the room it always keeps.
  Text {
    id: twoLines
    visible: false
    textFormat: Text.PlainText
    text: hero.keepLines > 1 ? "X\nX" : "X"
    font.family: hero.host.fontFamily
    font.pixelSize: Style.font.caption
  }

  PixelIcon {
    id: mark
    anchors.left: parent.left
    y: Math.round((hero.height - height) / 2)
    name: hero.icon
    size: hero.markSize
    color: hero.iconColor
  }

  Column {
    id: labels
    anchors.left: mark.right
    anchors.leftMargin: Style.space(10)
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)

    Item {
      width: parent.width
      height: Math.max(titleText.implicitHeight, actionRow.implicitHeight)

      Text {
        id: titleText
        anchors.left: parent.left
        anchors.right: actionRow.left
        anchors.rightMargin: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: hero.title
        color: hero.host.fg
        font.family: hero.host.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
      }

      Row {
        id: actionRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)
      }
    }

    // The prompt sign, then the line, hanging under its first word when it
    // wraps. The whole line is laid out from the first character and only
    // revealed as it types, the rest drawn clear, so a word never jumps to the
    // next line as it grows. The cursor takes the place of the next character
    // (the font is monospaced, so that moves nothing), and at the end sits in
    // a cell the layout always keeps for it.
    Item {
      width: parent.width
      height: Math.max(lineText.implicitHeight, twoLines.implicitHeight)

      Text {
        id: promptSign
        textFormat: Text.PlainText
        text: "❯"
        color: hero.lineColor
        font.family: hero.host.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        id: lineText
        anchors.left: promptSign.right
        anchors.leftMargin: Style.space(6)
        anchors.right: parent.right
        wrapMode: Text.Wrap
        textFormat: Text.StyledText
        text: hero.revealed
        color: hero.lineColor
        font.family: hero.host.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }
}
