import QtQuick
import qs.Commons

// A limit picked on a meter of cells, inside an open room: the label on the
// left, the value as it would be set on the right, the cells under them.
// Press or drag across the cells; it is written once, on release.
Column {
  id: pick

  required property var host
  property string label: ""
  property real value: 0
  property real from: 0
  property real to: 100
  property real step: 1
  property var floor: null
  property int segments: 10
  property string unit: ""
  property color tone: host.fg
  property bool interactive: true
  // The value as words, when a number alone says too little.
  property var format: null

  signal committed(real value)

  readonly property real shown: meter.dragging && !isNaN(meter.dragValue) ? meter.dragValue : value

  width: parent ? parent.width : 0
  spacing: Style.space(6)
  opacity: interactive ? 1 : 0.45

  Item {
    width: parent.width
    height: Math.max(labelText.implicitHeight, valueText.implicitHeight)

    MonoText {
      id: labelText
      anchors.left: parent.left
      anchors.right: valueText.left
      anchors.rightMargin: Style.space(8)
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
      text: pick.label
      color: pick.host.fg
      font.family: pick.host.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    MonoText {
      id: valueText
      anchors.right: parent.right
      textFormat: Text.PlainText
      text: typeof pick.format === "function" ? pick.format(pick.shown) : Math.round(pick.shown) + pick.unit
      color: pick.host.fg
      font.family: pick.host.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }
  }

  Meter {
    id: meter
    host: pick.host
    width: parent.width
    segments: pick.segments
    level: pick.to > pick.from ? (pick.value - pick.from) / (pick.to - pick.from) * 100 : 0
    tone: pick.tone
    foreground: pick.host.fg
    interactive: pick.interactive
    from: pick.from
    to: pick.to
    step: pick.step
    floor: pick.floor
    onCommitted: function(v) { pick.committed(v) }
  }
}
