import QtQuick
import qs.Commons
import qs.Commons as Commons
import "Rooms.js" as Rooms

// A room's number in the block face (Rooms.bigDigits), with its unit small
// beside it in the pixel type (°, W, Hz, %) and a mark over the unit, a pixel
// icon: charging, plugged in, hot. The mark's column is there either way, so
// nothing moves when one appears. The blocks are laid out on the font's
// character grid but drawn as rectangles, since typed block characters leave
// hairline seams. `value` follows the room's meter while it fills in, so the
// number counts up with it.
Item {
  id: figure

  property var value: null
  // The digits to draw in place of the rounded value, for a figure with a
  // decimal point (a fan's 4.3).
  property string text: ""
  // The reading it is counting toward (or its digits, as `text` is), so the
  // figure holds its width while it counts: 0 up to 95 widened under the
  // pointer, and the name beside it moved.
  property var target: null
  property string targetText: ""
  property string suffix: "%"
  property color tone: "white"
  property color foreground: "white"
  property string mark: ""
  // A reading that is off or stale reads quieter, as an unknown one does.
  property bool dimmed: false
  property string fontFamily: Style.font.family
  property real fontSize: Style.font.bodySmall
  readonly property real markSize: Math.round(fontSize * 1.1)

  readonly property bool known: text !== "" || Rooms.hasLevel(value)
  readonly property var rows: Rooms.bigDigits(text !== "" ? text : known ? String(Math.round(value)) : "--")
  readonly property int cols: rows[0].length
  readonly property int targetCols: targetText !== "" ? Rooms.bigDigits(targetText)[0].length
    : Rooms.hasLevel(target) ? Rooms.bigDigits(String(Math.round(target)))[0].length : 0
  // Columns kept for the digits; they sit at the right of them.
  readonly property int keptCols: Math.max(cols, targetCols)
  readonly property real shift: Math.round((keptCols - cols) * cellW)
  readonly property real cellW: grid.implicitWidth / 10
  readonly property real cellH: Math.round(metrics.height * 0.9)
  readonly property real digitsWidth: Math.round(keptCols * cellW)
  // Unknown, off or stale figures and the unit, tinted toward the panel
  // so they read on a light theme too.
  property color quiet: Qt.tint(foreground, Qt.rgba(Commons.Color.background.r, Commons.Color.background.g, Commons.Color.background.b, 0.4))
  readonly property color faceColor: known && !dimmed ? tone : quiet
  // Every block of every row, as [col, row, "full" | "top" | "bottom"].
  readonly property var blocks: {
    var out = []
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        var ch = rows[r].charAt(c)
        if (ch === "█") out.push([c, r, "full"])
        else if (ch === "▀") out.push([c, r, "top"])
        else if (ch === "▄") out.push([c, r, "bottom"])
      }
    }
    return out
  }

  implicitWidth: digitsWidth + Style.space(3) + side.implicitWidth
  // The face sits two and a half rows tall: nothing hangs below the bottom bar.
  implicitHeight: Math.round(cellH * 2.5)

  FontMetrics {
    id: metrics
    font.family: figure.fontFamily
    font.pixelSize: figure.fontSize
  }

  // The width of the font's own characters, measured as drawn.
  Text {
    id: grid
    visible: false
    text: "0000000000"
    font.family: figure.fontFamily
    font.pixelSize: figure.fontSize
  }

  Repeater {
    model: figure.blocks

    Rectangle {
      required property var modelData
      readonly property real from: modelData[1] * figure.cellH + (modelData[2] === "bottom" ? figure.cellH / 2 : 0)
      x: figure.shift + Math.round(modelData[0] * figure.cellW)
      y: Math.round(from)
      width: figure.shift + Math.round((modelData[0] + 1) * figure.cellW) - x
      height: Math.round(from + (modelData[2] === "full" ? figure.cellH : figure.cellH / 2)) - y
      color: figure.faceColor
      antialiasing: false
    }
  }

  // The mark over the unit, in one column as wide as the wider of the two.
  // A degree sign rides the top of the digits, as it is written, and the
  // mark then sits under it.
  readonly property bool unitTop: suffix === "°"

  Item {
    id: side
    x: figure.digitsWidth + Style.space(3)
    implicitWidth: Math.max(unitText.implicitWidth, markIcon.implicitWidth)
    height: figure.implicitHeight

    // A mark plays as it appears. Hot keeps the mercury climbing and a GPU
    // switch waiting on a restart keeps its arrow going round, now and then,
    // since both wait on something.
    PixelIcon {
      id: markIcon
      visible: figure.mark !== ""
      loop: figure.mark === "thermometer" || figure.mark === "reload" ? "burst" : ""
      loopEvery: figure.mark === "thermometer" ? 2400 : 4800
      onNameChanged: if (name !== "") play(0)
      anchors.horizontalCenter: parent.horizontalCenter
      y: figure.unitTop ? parent.height - height : 0
      name: figure.mark
      size: figure.markSize
      color: figure.dimmed ? figure.quiet : figure.tone
    }

    PixelText {
      id: unitText
      visible: figure.known && figure.suffix !== ""
      anchors.left: parent.left
      y: figure.unitTop ? 0 : parent.height - height
      text: figure.suffix
      size: Style.font.caption * 0.75
      color: figure.quiet
    }
  }
}
