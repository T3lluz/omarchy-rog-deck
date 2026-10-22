import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Equal-width row of options, pick one. `options` is [{ value, label,
// icon?, hint? }]; `picked(value)` fires only for a different option.
Row {
  id: seg

  property var options: []
  property var value
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  property bool interactive: true

  signal picked(var value)

  spacing: Style.space(6)

  readonly property real cellWidth: options.length > 0
    ? (width - spacing * (options.length - 1)) / options.length : 0

  Repeater {
    model: seg.options

    Button {
      required property var modelData
      width: seg.cellWidth
      text: modelData.label
      iconText: modelData.icon || ""
      iconSize: Style.font.body
      tooltipText: modelData.hint || ""
      fontSize: Style.font.bodySmall
      foreground: seg.foreground
      fontFamily: seg.fontFamily
      bordered: true
      active: seg.value === modelData.value
      opacity: seg.interactive ? 1 : 0.45
      onClicked: if (seg.interactive && seg.value !== modelData.value) seg.picked(modelData.value)
    }
  }
}
