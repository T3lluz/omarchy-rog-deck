import QtQuick
import qs.Commons
import qs.Ui
import "Rooms.js" as Rooms

// A level drawn as Batteries draws a battery: an outlined body split into
// cells (Rooms.meterCells), each filled to the full height of the body. It
// fills in from empty when the panel opens and slides to a new level after
// that. The pointer presses the cells under it down a little, and `press`
// sends a ripple out from a point, as Weave's pad does. A limit (the charge
// limit) is a tick through the body.
//
// With `interactive` it is a fader too, as in Sonus: press or drag across it
// to pick a value from `from` to `to` in `step`s, with a tick where the
// pointer would set it. `committed(value)` fires once, on release, so a drag
// writes to the hardware once.
Item {
  id: meter

  required property var host
  // What is drawn, 0..100.
  property real level: 0
  property bool known: true
  property int segments: 10
  property color tone: "white"
  property color foreground: "white"
  // A tick through the body at this level (0..100), or -1 for none.
  property real limit: -1
  // How long after the panel opens this one starts filling, in ms, so the
  // panel fills from the top down.
  property int delay: 0
  // Small meters (a part cell's) draw a thinner body.
  property bool small: false
  property bool dimmed: false
  property bool interactive: false
  property real from: 0
  property real to: 100
  property real step: 1
  // The smallest value a press may pick, when the range drawn starts lower
  // (a charge limit is drawn from 0 but stops at 20).
  property var floor: null
  // A few levels, one per cell (a light's Low, Med, High): a press anywhere
  // in a cell picks that cell's level, rather than the nearest step to the
  // pointer, which made the middle of a cell a coin toss.
  property bool perCell: false
  property string tipText: ""

  signal previewed(real value)
  signal committed(real value)

  // What is drawn: the level while it fills in, else the level.
  property real shown: 0
  property var dent: null
  property var ripples: []
  readonly property bool dragging: area.pressed
  readonly property bool hot: area.containsMouse || dragging
  readonly property real pointerValue: area.containsMouse || dragging ? valueAt(area.mouseX) : NaN
  // The value being dragged to, NaN otherwise.
  property real dragValue: NaN

  readonly property real line: Math.max(1, Style.space(1))
  readonly property real inset: small ? Math.max(1, Style.space(1)) : Math.max(2, Style.space(2))
  readonly property real gap: small ? Math.max(1, Style.space(1)) : Math.max(2, Style.space(2))

  implicitHeight: small ? Style.space(11) : Style.space(18)

  readonly property var cells: Rooms.meterCells({
    segments: segments,
    level: known ? shown : 0,
    dent: dent,
    ripples: ripples.map(function(r) { return { x: r.x, age: meter.host.clock - r.at } })
  })

  function valueAt(x) {
    if (perCell) return from + Rooms.cellAt(x - cellRow.x, cellRow.width, segments) * (to - from) / segments
    return Rooms.faderValue(x - cellRow.x, cellRow.width, from, to, step, floor)
  }

  function levelOf(v) {
    return to > from ? (v - from) / (to - from) * 100 : 0
  }

  // Old ripples go once they have run out.
  Connections {
    target: meter.host
    enabled: meter.ripples.length > 0
    function onClockChanged() {
      var left = meter.ripples.filter(function(r) { return meter.host.clock - r.at < Rooms.METER.RIPPLE_MS })
      if (left.length !== meter.ripples.length) meter.ripples = left
    }
  }

  Connections {
    target: meter.host
    function onEntryChanged() { meter.enter() }
  }

  function enter() {
    fillIn.stop()
    settle.stop()
    if (Style.reduceMotion || !known) { shown = known ? level : 0; return }
    shown = 0
    fillTo.to = level
    fillIn.start()
  }

  // The target is set as the slide starts: bound, it still held the old
  // level when the change arrived, and the slide went nowhere.
  function slide() {
    settle.stop()
    settle.to = level
    settle.start()
  }

  // A point in the meter's own coordinates. Only near the body presses.
  function hover(x, y) {
    if (x < 0 || x > body.width || y < -height * 0.6 || y > height * 1.6) { dent = null; return }
    dent = x / body.width
  }

  function press(x, y) {
    if (Style.reduceMotion) return
    var next = ripples.slice(-3)
    next.push({ x: Math.max(0, Math.min(1, x / body.width)), at: host.clock })
    ripples = next
  }

  function dragTo(x) {
    var v = valueAt(x)
    fillIn.stop()
    settle.stop()
    dragValue = v
    shown = levelOf(v)
    previewed(v)
  }

  property bool ready: false

  Component.onCompleted: {
    shown = known ? level : 0
    ready = true
  }

  // A new reading slides there; only the panel opening fills from empty.
  onLevelChanged: {
    if (!ready || fillIn.running || dragging) return
    if (Style.reduceMotion || !host.opened) { shown = level; return }
    slide()
  }

  SequentialAnimation {
    id: fillIn
    PauseAnimation { duration: Style.duration(meter.delay) }
    NumberAnimation { id: fillTo; target: meter; property: "shown"; duration: Style.duration(680); easing.type: Easing.OutCubic }
    // The level may have moved on while it filled in.
    ScriptAction { script: if (meter.shown !== meter.level) meter.slide() }
  }

  NumberAnimation {
    id: settle
    target: meter
    property: "shown"
    duration: Style.duration(420)
    easing.type: Easing.OutCubic
  }

  Rectangle {
    id: body
    width: parent.width
    height: parent.height
    color: "transparent"
    radius: Style.cornerRadius > 0 ? Math.min(Style.cornerRadius, 3) : 0
    border.width: meter.line
    border.color: Qt.rgba(meter.tone.r, meter.tone.g, meter.tone.b, meter.known && !meter.dimmed ? (meter.hot ? 0.85 : 0.6) : 0.3)
    opacity: meter.dimmed ? 0.5 : 1

    Row {
      id: cellRow
      x: meter.line + meter.inset
      y: meter.line + meter.inset
      width: body.width - x * 2
      height: body.height - y * 2
      spacing: meter.gap

      readonly property real cellWidth: (width - spacing * (meter.segments - 1)) / meter.segments

      Repeater {
        model: meter.segments

        Item {
          id: cell
          required property int index
          readonly property var c: meter.cells[index] || ({ fill: 0, glow: 0, press: 0 })

          width: cellRow.cellWidth
          height: cellRow.height
          // A cell gives under the pointer, as Weave's tiles do.
          scale: 1 - cell.c.press * 0.14

          Rectangle {
            anchors.fill: parent
            color: Qt.rgba(meter.tone.r, meter.tone.g, meter.tone.b, 0.12)
            antialiasing: false
          }

          Rectangle {
            width: parent.width * cell.c.fill
            height: parent.height
            color: meter.tone
            antialiasing: false
          }

          Rectangle {
            visible: cell.c.glow > 0.01
            anchors.fill: parent
            color: Qt.rgba(meter.foreground.r, meter.foreground.g, meter.foreground.b, cell.c.glow * 0.55)
            antialiasing: false
          }
        }
      }
    }
  }

  // A limit, as Batteries marks a charge limit: a tick through the body,
  // poking out above and below.
  Rectangle {
    visible: meter.limit >= 0 && meter.limit < 100
    x: Math.round(cellRow.x + cellRow.width * meter.limit / 100 - width / 2)
    y: -Math.max(2, Style.space(3))
    width: meter.line
    height: parent.height - y * 2
    color: meter.foreground
    opacity: 0.55
    antialiasing: false
  }

  // Where a press would set it.
  Rectangle {
    visible: meter.interactive && !isNaN(meter.pointerValue)
    x: Math.round(cellRow.x + cellRow.width * meter.levelOf(meter.pointerValue) / 100 - width / 2)
    y: -Math.max(2, Style.space(3))
    width: meter.line
    height: parent.height - y * 2
    color: meter.foreground
    opacity: 0.55
    antialiasing: false
  }

  MouseArea {
    id: area
    enabled: meter.interactive
    // A little taller than the body, so a thin meter is easy to catch.
    x: 0
    y: -Style.space(4)
    width: parent.width
    height: parent.height + Style.space(8)
    hoverEnabled: true
    preventStealing: true
    cursorShape: Qt.PointingHandCursor

    onPositionChanged: function(mouse) {
      meter.hover(mouse.x, mouse.y + y)
      if (pressed) meter.dragTo(mouse.x)
    }
    onExited: meter.dent = null
    onPressed: function(mouse) {
      // The clock first: a ripple is stamped with it.
      meter.host.wake(Rooms.METER.RIPPLE_MS + 200)
      meter.press(mouse.x, mouse.y)
      meter.dragTo(mouse.x)
    }
    onReleased: {
      var v = meter.dragValue
      meter.dragValue = NaN
      if (!isNaN(v)) meter.committed(v)
      if (meter.shown !== meter.level) meter.slide()
    }
  }

  PanelToolTip {
    visible: area.containsMouse && !meter.dragging && meter.tipText !== ""
    text: meter.tipText
    fontFamily: meter.host.fontFamily
  }
}
