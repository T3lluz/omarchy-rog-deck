import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// Per-mode fan curves, written to asusd's own per-profile store. asusd puts
// a mode's curve on the fans whenever that mode becomes active.
Column {
  id: tab

  property var deck: null
  readonly property var service: deck ? deck.service : null
  readonly property var status: deck ? deck.status : null
  readonly property var curves: service ? service.fanCurves : null

  // The mode whose curve is shown; follows the active mode until picked.
  property string pickedMode: ""
  property string fan: "cpu"
  readonly property string mode: pickedMode || deck.activeProfile || "balanced"
  readonly property var curveData: curves && curves[mode] ? curves[mode] : null
  readonly property bool custom: curveData ? !!service.pick("fans." + mode, curveData.custom) : false
  readonly property var fans: curveData ? Object.keys(curveData.fans) : []
  readonly property var points: curveData && curveData.fans[fan] ? curveData.fans[fan].points : []

  spacing: Style.space(12)

  onVisibleChanged: if (visible && service) service.refreshFans()

  SectionLabel { text: "MODE"; foreground: tab.deck.fg; fontFamily: tab.deck.fontFamily }

  Seg {
    width: parent.width
    options: tab.deck.profiles.map(function(p) {
      return { value: p.key, label: p.label + (p.key === tab.deck.activeProfile ? " •" : "") }
    })
    value: tab.mode
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onPicked: function(v) { tab.pickedMode = v }
  }

  SwitchRow {
    width: parent.width
    visible: !!tab.curveData
    label: "Custom fan curve"
    hint: tab.custom ? "Runs whenever " + Model.profileInfo(tab.mode).label + " is on"
                     : "Firmware curve. Yours below is kept for later"
    checked: tab.custom
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onToggled: tab.service.setFanCustom(tab.mode, !tab.custom)
  }

  Seg {
    width: parent.width
    visible: tab.fans.length > 1
    options: tab.fans.map(function(f) { return { value: f, label: f.toUpperCase() + " fan" } })
    value: tab.fan
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onPicked: function(v) { tab.fan = v }
  }

  FanCurve {
    id: curve
    width: parent.width
    visible: !!tab.curveData
    points: tab.points
    editable: tab.custom
    liveTemp: tab.status && tab.status.temps && tab.mode === tab.deck.activeProfile
      ? (tab.fan === "gpu" ? (tab.status.temps.gpu || -1) : (tab.status.temps.cpu || -1)) : -1
    foreground: tab.deck.fg
    accent: tab.deck.accent
    fontFamily: tab.deck.fontFamily
    onEdited: function(pts) { tab.service.setFanCurve(tab.mode, tab.fan, pts) }
  }

  // Exact values for the selected point.
  Item {
    id: pointEditor
    width: parent.width
    height: Math.max(prevPoint.implicitHeight, tempField.implicitHeight)
    visible: !!tab.curveData && tab.custom && curve.working.length > 0

    readonly property int index: Math.max(0, Math.min(curve.working.length - 1, curve.selectedIndex))
    readonly property var point: curve.working.length > 0 ? curve.working[index] : ({ t: 0, p: 0 })
    property int pendingT: 0
    property int pendingP: 0

    function queue(t, p) {
      pendingT = t
      pendingP = p
      pointCommit.restart()
    }

    Timer {
      id: pointCommit
      interval: 600
      onTriggered: curve.setPoint(pointEditor.index, pointEditor.pendingT, pointEditor.pendingP)
    }

    Row {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      Button {
        id: prevPoint
        iconText: "󰅁"
        tooltipText: "Previous point"
        foreground: tab.deck.fg
        fontFamily: tab.deck.fontFamily
        bordered: true
        onClicked: curve.selectedIndex = Math.max(0, pointEditor.index - 1)
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "Point " + (pointEditor.index + 1) + "/" + curve.working.length
        color: tab.deck.fg
        font.family: tab.deck.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Button {
        iconText: "󰅂"
        tooltipText: "Next point"
        foreground: tab.deck.fg
        fontFamily: tab.deck.fontFamily
        bordered: true
        onClicked: curve.selectedIndex = Math.min(curve.working.length - 1, pointEditor.index + 1)
      }
    }

    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(8)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "°C"
        color: tab.deck.fg
        opacity: 0.6
        font.family: tab.deck.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      NumberField {
        id: tempField
        anchors.verticalCenter: parent.verticalCenter
        fieldWidth: Style.space(70)
        fontSize: Style.font.bodySmall
        from: pointEditor.index > 0 ? curve.working[pointEditor.index - 1].t : 20
        to: pointEditor.index < curve.working.length - 1 ? curve.working[pointEditor.index + 1].t : 110
        value: pointEditor.point.t
        foreground: tab.deck.fg
        fontFamily: tab.deck.fontFamily
        onModified: function(v) { pointEditor.queue(v, pointEditor.point.p) }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "%"
        color: tab.deck.fg
        opacity: 0.6
        font.family: tab.deck.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      NumberField {
        anchors.verticalCenter: parent.verticalCenter
        fieldWidth: Style.space(70)
        fontSize: Style.font.bodySmall
        from: 0
        to: 100
        stepSize: 1
        value: pointEditor.point.p
        foreground: tab.deck.fg
        fontFamily: tab.deck.fontFamily
        onModified: function(v) { pointEditor.queue(pointEditor.point.t, v) }
      }
    }
  }

  Text {
    width: parent.width
    visible: !!tab.curveData
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    text: {
      var live = tab.status && tab.status.fans ? tab.status.fans[tab.fan] : null
      var parts = []
      if (live !== null && live !== undefined) parts.push(tab.fan.toUpperCase() + " fan " + Model.rpm(live) + " rpm now")
      parts.push(tab.custom ? "Drag a bar, or pick a point and type exact values" : "Turn on the custom curve to edit")
      return parts.join(" · ")
    }
    color: tab.deck.fg
    opacity: 0.55
    font.family: tab.deck.fontFamily
    font.pixelSize: Style.font.caption
  }

  Text {
    width: parent.width
    visible: !tab.curveData
    textFormat: Text.PlainText
    text: tab.curves ? "This laptop has no fan curves in asusd." : "Reading fan curves…"
    color: tab.deck.fg
    opacity: 0.6
    font.family: tab.deck.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  SectionLabel { text: "PRESETS"; foreground: tab.deck.fg; fontFamily: tab.deck.fontFamily; visible: !!tab.curveData }

  Seg {
    width: parent.width
    visible: !!tab.curveData
    options: Model.FAN_PRESETS.concat([{ value: "reset", label: "Reset", hint: "Firmware curve, custom off" }])
    value: ""
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onPicked: function(v) {
      if (v === "reset") tab.service.resetFans(tab.mode)
      else tab.service.setFanPreset(tab.mode, v)
    }
  }
}
