import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A labelled slider with its value on the right: either as text (`format`)
// or, with `showField`, as a number field for typing an exact value.
// `committed(value)` fires once per drag, click or typed value.
Column {
  id: field

  property string label: ""
  property real value: 0
  property real from: 0
  property real to: 100
  property real step: 1
  property int tickCount: 0
  property bool showField: false
  property string suffix: ""
  property var format: null
  property bool interactive: true
  property var bar: null
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  signal committed(real value)

  readonly property real shown: slider.dragging ? slider.liveValue : value
  property real pendingValue: 0

  spacing: Style.space(6)
  opacity: interactive ? 1 : 0.45

  function text(v) {
    if (typeof format === "function") return format(v)
    var digits = step < 1 ? (step < 0.1 ? 2 : 1) : 0
    return Number(v).toFixed(digits) + suffix
  }

  Item {
    width: parent.width
    height: Math.max(labelText.implicitHeight, valueText.implicitHeight)
    visible: field.label !== "" || !field.showField

    Text {
      id: labelText
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: field.label
      color: field.foreground
      opacity: 0.6
      font.family: field.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Text {
      id: valueText
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: !field.showField
      textFormat: Text.PlainText
      text: field.text(field.shown)
      color: field.foreground
      font.family: field.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }
  }

  Item {
    width: parent.width
    height: Math.max(slider.implicitHeight, numberField.visible ? numberField.implicitHeight : 0)

    PanelSlider {
      id: slider
      anchors.left: parent.left
      anchors.right: numberField.visible ? numberField.left : parent.right
      anchors.rightMargin: numberField.visible ? Style.space(10) : 0
      anchors.verticalCenter: parent.verticalCenter
      bar: field.bar
      enabled: field.interactive
      minimum: field.from
      maximum: field.to
      step: field.step
      integer: field.step >= 1
      tickCount: field.tickCount
      value: field.value
      onReleased: function(v) { if (field.interactive) field.committed(v) }
    }

    NumberField {
      id: numberField
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: field.showField
      enabled: field.interactive
      fieldWidth: Style.space(76)
      fontSize: Style.font.bodySmall
      from: Math.round(field.from)
      to: Math.round(field.to)
      stepSize: Math.max(1, Math.round(field.step))
      value: Math.round(field.shown)
      foreground: field.foreground
      fontFamily: field.fontFamily
      // Arrow presses and typing each fire; wait for a pause.
      onModified: function(v) {
        field.pendingValue = v
        commitTimer.restart()
      }
    }
  }

  Timer {
    id: commitTimer
    interval: 600
    onTriggered: field.committed(field.pendingValue)
  }
}
