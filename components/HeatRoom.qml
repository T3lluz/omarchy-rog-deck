import QtQuick
import qs.Commons
import "../Model.js" as Model
import "Rooms.js" as Rooms

// The CPU and the GPU side by side, most of a row wide. Each part is a header
// of its own, as every room has one: its icon, its name over how warm it runs
// (Cool, Warm, Hot, or Asleep for a GPU that is off), and its temperature in
// the block face on the right, over ten cells of it (0 to 100 °C). The GPU
// is never woken to read it. Its drawer (HeatDrawer) holds the fans, the
// draw and the bar switches.
Room {
  id: room

  readonly property var status: host.status
  readonly property var parts: Model.fanParts(status)
  // The cells are kept while the parts stay the same, so a refresh moves
  // their meters and figures instead of building them again from empty.
  property var partKeys: []
  onPartsChanged: {
    var keys = parts.map(function(p) { return p.key })
    if (keys.join() !== partKeys.join()) partKeys = keys
  }
  Component.onCompleted: partKeys = parts.map(function(p) { return p.key })

  tone: host.toneOf("heat")
  expanded: host.openRoom === "heat"
  cells: {
    var out = []
    for (var i = 0; i < partRepeater.count; i++) {
      var it = partRepeater.itemAt(i)
      if (it) out.push(it.meter)
    }
    return out
  }
  onClicked: host.toggleRoom("heat")

  Row {
    id: partRow
    width: parent.width
    spacing: Style.space(16)

    Repeater {
      id: partRepeater
      model: room.partKeys

      Column {
        id: part
        required property int index
        readonly property var modelData: room.parts[index] || ({ key: "", label: "", icon: "", temp: null, warmth: "", hot: false })
        readonly property alias meter: partMeter
        readonly property bool known: Rooms.hasLevel(modelData.temp)
        width: (partRow.width - partRow.spacing * (room.partKeys.length - 1)) / Math.max(1, room.partKeys.length)
        spacing: Style.space(8)

        RoomHeader {
          host: room.host
          icon: part.modelData.icon
          tone: room.tone
          figureTone: part.modelData.hot ? room.host.lowTone : room.tone
          title: part.modelData.label
          status: part.modelData.warmth
          value: part.known ? part.modelData.temp : null
          suffix: "°"
          figureDimmed: !part.known
          dimmed: !part.known
          mark: part.modelData.hot ? "thermometer" : ""
          expanded: room.expanded
          delay: room.delay + 120 + part.index * 60
          tick: room.story
          // Crossing from cool to warm to hot plays the part again.
          cue: part.modelData.warmth
        }

        Meter {
          id: partMeter
          host: room.host
          width: parent.width
          segments: 10
          level: part.known ? Math.max(0, Math.min(100, part.modelData.temp)) : 0
          known: part.known
          tone: part.modelData.hot ? room.host.lowTone : room.tone
          foreground: room.host.fg
          delay: room.delay + 80 + part.index * 60
        }
      }
    }
  }
}
