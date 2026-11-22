import QtQuick
import qs.Commons
import "Rooms.js" as Rooms

// A figure's number as it is drawn: it counts up from zero when the panel
// opens, then slides to each new reading (420 ms) instead of jumping, and
// never starts over when the data refreshes.
Item {
  id: counter

  required property var host
  // The reading, or null when there is none.
  property var value: null
  // How long after the panel opens it starts counting, in ms.
  property int delay: 0
  property real shown: 0
  readonly property bool known: Rooms.hasLevel(value)
  property bool ready: false

  function enter() {
    countUp.stop()
    settle.stop()
    if (Style.reduceMotion || !known) { shown = known ? value : 0; return }
    shown = 0
    countTo.to = value
    countUp.start()
  }

  // The target is set as the slide starts: bound, it still held the old
  // reading when the change arrived, and the slide went nowhere.
  function slide() {
    settle.stop()
    settle.to = value
    settle.start()
  }

  Connections {
    target: counter.host
    function onEntryChanged() { counter.enter() }
  }

  Component.onCompleted: {
    shown = known ? value : 0
    ready = true
  }

  onValueChanged: {
    if (!ready || !known || countUp.running) return
    if (Style.reduceMotion || !host.opened) { shown = value; return }
    slide()
  }

  SequentialAnimation {
    id: countUp
    PauseAnimation { duration: Style.duration(counter.delay) }
    NumberAnimation { id: countTo; target: counter; property: "shown"; duration: Style.duration(680); easing.type: Easing.OutCubic }
    // The reading may have moved on while it counted.
    ScriptAction { script: if (counter.known && counter.shown !== counter.value) counter.slide() }
  }

  NumberAnimation {
    id: settle
    target: counter
    property: "shown"
    duration: Style.duration(420)
    easing.type: Easing.OutCubic
  }
}
