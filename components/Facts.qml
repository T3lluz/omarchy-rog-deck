import QtQuick
import qs.Commons

// Readings two to a line, as Batteries lays out a room's details: the label
// dim on the left, the value on the right, wrapping rather than cut. Values
// decode as the panel opens, like the rest of the room's text.
Grid {
  id: factGrid

  required property var host
  // [{ label, value }]
  property var facts: []
  property int delay: 0

  visible: facts.length > 0
  width: parent ? parent.width : 0
  columns: 2
  columnSpacing: Style.space(20)
  rowSpacing: Style.space(4)

  readonly property real cellWidth: (width - columnSpacing) / 2

  // By count, so a refresh changes the values in place instead of building
  // the rows again.
  Repeater {
    model: factGrid.facts.length

    Item {
      id: pair
      required property int index
      readonly property var modelData: factGrid.facts[index] || ({ label: "", value: "" })
      width: factGrid.cellWidth
      implicitHeight: Math.max(pairLabel.implicitHeight, pairValue.implicitHeight)

      MonoText {
        id: pairLabel
        width: Math.min(implicitWidth, pair.width * 0.55)
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: pair.modelData.label
        color: factGrid.host.fg
        opacity: 0.6
        font.family: factGrid.host.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Decode {
        id: pairValue
        host: factGrid.host
        anchors.right: parent.right
        width: Math.min(implicitWidth, pair.width - pairLabel.width - Style.space(8))
        horizontalAlignment: Text.AlignRight
        wrapMode: Text.Wrap
        value: pair.modelData.value
        delay: factGrid.delay + pair.index * 40
        color: factGrid.host.fg
        font.family: factGrid.host.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }
  }
}
