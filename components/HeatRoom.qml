import QtQuick
import qs.Commons
import "../Model.js" as Model
import "Rooms.js" as Rooms

// The CPU and the GPU side by side, most of a row wide, each its
// temperature in the block face over ten cells of it (0 to 100 °C) and what
// its fan does, under how hot the two run. The GPU reads nothing while it sleeps; it is never woken to read
// it. Its drawer (HeatDrawer) holds the readings and their bar switches.
Room {
  id: room

  readonly property var status: host.status
  readonly property var parts: Model.fanParts(status)

  tone: host.toneOf("heat")
  expanded: host.openRoom === "heat"
  headerNatural: header.naturalHeight
  cells: {
    var out = []
    for (var i = 0; i < partRepeater.count; i++) {
      var it = partRepeater.itemAt(i)
      if (it) out.push(it.meter)
    }
    return out
  }
  onClicked: host.toggleRoom("heat")

  RoomHeader {
    id: header
    host: room.host
    minHeight: room.headerMin
    icon: "thermometer"
    tone: room.tone
    title: "CPU and GPU"
    status: Model.heatState(room.status ? room.status.temps : null)
    showFigure: false
    expanded: room.expanded
    delay: room.delay + 120
    story: Rooms.storyOf("heat")
    tick: room.story
  }

  Row {
    id: partRow
    width: parent.width
    spacing: Style.space(14)

    Repeater {
      id: partRepeater
      model: room.parts

      Column {
        id: part
        required property var modelData
        required property int index
        readonly property alias meter: partMeter
        readonly property bool known: Rooms.hasLevel(modelData.temp)
        width: (partRow.width - partRow.spacing * (room.parts.length - 1)) / Math.max(1, room.parts.length)
        spacing: Style.space(4)

        // The part's own icon, the chip or the graphics card, beside its
        // temperature; its name goes in the line under the meter, so a
        // narrow cell never squeezes the two together.
        Row {
          spacing: Style.space(6)

          PixelIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: part.modelData.icon
            size: Style.font.title
            color: part.known ? room.tone : room.host.dim
          }

          BigFigure {
            anchors.verticalCenter: parent.verticalCenter
            value: part.known ? partMeter.shown : null
            suffix: "°"
            tone: part.modelData.hot ? room.host.lowTone : room.tone
            foreground: room.host.fg
            mark: part.modelData.hot ? "thermometer" : ""
            fontFamily: room.host.fontFamily
          }
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

        Decode {
          host: room.host
          width: parent.width
          wrapMode: Text.Wrap
          value: part.modelData.label + " · " + part.modelData.state
          delay: room.delay + 160
          color: room.host.dim
          font.family: room.host.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
