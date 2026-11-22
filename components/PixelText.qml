import QtQuick
import QtQuick.Window
import "Rooms.js" as Rooms

// A line in the pixel type (Rooms.pixelText): small figures and their units,
// drawn as rectangles on whole device pixels. `unit` is device pixels per
// cell, the same unit a PixelIcon beside it takes so their strokes match; 0
// picks it from `size`, the height of a capital in logical pixels.
Item {
  id: line

  property string text: ""
  property color color: "white"
  property real size: 9
  property int unit: 0

  readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
  readonly property int px: unit > 0 ? unit : Math.max(1, Math.round(size * dpr / 5))
  readonly property real cell: px / dpr
  readonly property var shape: Rooms.pixelText(text)

  implicitWidth: shape.width * cell
  implicitHeight: shape.height * cell

  // Laid from a whole device pixel, as PixelIcon is, so rounding never
  // doubles a stroke.
  property real snapX: 0
  property real snapY: 0

  function snap() {
    if (!visible) return
    var p = line.mapToItem(null, 0, 0)
    var dx = Math.round(p.x * dpr) / dpr - p.x
    var dy = Math.round(p.y * dpr) / dpr - p.y
    if (Math.abs(dx - snapX) > 0.001) snapX = dx
    if (Math.abs(dy - snapY) > 0.001) snapY = dy
  }

  Component.onCompleted: snap()

  Connections {
    target: line.Window.window
    ignoreUnknownSignals: true
    function onAfterAnimating() { line.snap() }
  }

  Item {
    x: line.snapX
    y: line.snapY

    Repeater {
      model: line.shape.rects

      Rectangle {
        required property var modelData
        x: modelData[0] * line.px / line.dpr
        y: modelData[1] * line.px / line.dpr
        width: modelData[2] * line.px / line.dpr
        height: modelData[3] * line.px / line.dpr
        color: line.color
        antialiasing: false
      }
    }
  }
}
