import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../Model.js" as Model

// Eight-point fan curve. Drag a bar to set its duty, scroll a temperature
// to move it. The EC interpolates between points; `edited(points)` fires
// once per drag or after the scrolling stops.
Item {
  id: chart

  property var points: []
  property bool editable: true
  property real liveTemp: -1
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family

  property var working: []
  property bool dragging: false
  property int activeIndex: -1
  // The point the number fields under the chart edit.
  property int selectedIndex: 0

  signal edited(var points)

  implicitHeight: Style.space(150)

  readonly property real labelHeight: Style.font.caption + Style.space(8)
  readonly property real plotHeight: height - labelHeight
  readonly property real colWidth: working.length > 0 ? width / working.length : 0

  function copy(list) {
    return (list || []).map(function(p) { return { t: p.t, p: p.p } })
  }

  onPointsChanged: if (!dragging && !tempCommit.running) working = copy(points)
  Component.onCompleted: working = copy(points)

  function setFromMouse(mx, my) {
    if (working.length === 0) return
    var i = Math.max(0, Math.min(working.length - 1, Math.floor(mx / colWidth)))
    var p = (1 - my / plotHeight) * 100
    var next = copy(working)
    next[i] = Model.clampPoint(next, i, next[i].t, p)
    working = next
    activeIndex = i
    selectedIndex = i
  }

  // Set one point exactly (from the number fields) and commit it.
  function setPoint(i, t, p) {
    if (i < 0 || i >= working.length) return
    var next = copy(working)
    next[i] = Model.clampPoint(next, i, t, p)
    working = next
    chart.edited(chart.copy(chart.working))
  }

  function nudgeTemp(i, delta) {
    var next = copy(working)
    next[i] = Model.clampPoint(next, i, next[i].t + delta, next[i].p)
    working = next
    tempCommit.restart()
  }

  Timer {
    id: tempCommit
    interval: 700
    onTriggered: chart.edited(chart.copy(chart.working))
  }

  // Where the live temperature falls between the points.
  readonly property real liveX: {
    if (liveTemp < 0 || working.length === 0) return -1
    if (liveTemp <= working[0].t) return colWidth / 2
    for (var i = 1; i < working.length; i++) {
      if (liveTemp <= working[i].t) {
        var span = Math.max(1, working[i].t - working[i - 1].t)
        return colWidth * (i - 1 + 0.5 + (liveTemp - working[i - 1].t) / span)
      }
    }
    return width - colWidth / 2
  }

  Repeater {
    model: chart.working.length

    Item {
      required property int index
      readonly property var point: chart.working[index]
      x: index * chart.colWidth
      width: chart.colWidth
      height: chart.height

      Rectangle {
        id: track
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(6, chart.colWidth * 0.5)
        height: chart.plotHeight
        radius: Math.min(width / 2, Style.cornerRadius)
        color: Qt.rgba(chart.foreground.r, chart.foreground.g, chart.foreground.b, 0.08)
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: track.bottom
        width: track.width
        height: Math.max(2, chart.plotHeight * point.p / 100)
        radius: track.radius
        color: chart.editable ? chart.accent : chart.foreground
        opacity: chart.editable ? (chart.activeIndex === index || chart.selectedIndex === index ? 1 : 0.7) : 0.35
        border.width: chart.editable && chart.selectedIndex === index ? Math.max(1, Style.space(1)) : 0
        border.color: chart.foreground
        Behavior on height { enabled: !chart.dragging; NumberAnimation { duration: 160 } }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(0, chart.plotHeight - chart.plotHeight * point.p / 100 - height - Style.space(2))
        visible: chart.dragging && chart.activeIndex === index
        textFormat: Text.PlainText
        text: point.p + "%"
        color: chart.foreground
        font.family: chart.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        textFormat: Text.PlainText
        text: point.t + "°"
        color: chart.foreground
        opacity: tempArea.containsMouse || (chart.editable && chart.selectedIndex === index) ? 1 : 0.6
        font.bold: chart.editable && chart.selectedIndex === index
        font.family: chart.fontFamily
        font.pixelSize: Style.font.caption

        MouseArea {
          id: tempArea
          anchors.fill: parent
          anchors.margins: -Style.space(4)
          enabled: chart.editable
          hoverEnabled: true
          onWheel: function(wheel) { chart.nudgeTemp(index, wheel.angleDelta.y > 0 ? 1 : -1) }
        }
      }
    }
  }

  // Live temperature marker.
  Rectangle {
    visible: chart.liveX >= 0
    x: chart.liveX
    width: 1
    height: chart.plotHeight
    color: chart.foreground
    opacity: 0.4
  }

  MouseArea {
    width: parent.width
    height: chart.plotHeight
    enabled: chart.editable
    cursorShape: Qt.SizeVerCursor
    preventStealing: true
    onPressed: function(mouse) { chart.dragging = true; chart.setFromMouse(mouse.x, mouse.y) }
    onPositionChanged: function(mouse) { if (chart.dragging) chart.setFromMouse(mouse.x, mouse.y) }
    onReleased: {
      chart.dragging = false
      chart.activeIndex = -1
      chart.edited(chart.copy(chart.working))
    }
  }
}
