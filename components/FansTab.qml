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
  readonly property var liveFans: status && status.fans ? status.fans : ({})

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

  // ---------- Mode ----------
  SectionHeader {
    icon: "󰈐"
    title: "FAN CURVE"
    detail: {
      var parts = []
      if (tab.liveFans.cpu !== null && tab.liveFans.cpu !== undefined) parts.push("CPU " + Model.rpm(tab.liveFans.cpu))
      if (tab.liveFans.gpu !== null && tab.liveFans.gpu !== undefined) parts.push("GPU " + Model.rpm(tab.liveFans.gpu))
      return parts.length ? parts.join(" · ") + " RPM" : ""
    }
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
  }

  Seg {
    width: parent.width
    options: tab.deck.profiles.map(function(p) {
      return { value: p.key, label: p.label, icon: p.icon,
               hint: p.key === tab.deck.activeProfile ? "The mode that is on now" : "Edit this mode's curve" }
    })
    value: tab.mode
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onPicked: function(v) { tab.pickedMode = v }
  }

  SwitchRow {
    width: parent.width
    visible: !!tab.curveData
    icon: "󰄪"
    label: "Custom curve for " + Model.profileInfo(tab.mode).label
    hint: tab.custom ? (tab.mode === tab.deck.activeProfile ? "Running now" : "Runs when " + Model.profileInfo(tab.mode).label + " is on")
                     : "Off: the firmware decides. Your curve is kept"
    checked: tab.custom
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onToggled: tab.service.setFanCustom(tab.mode, !tab.custom)
  }

  PanelSeparator { foreground: tab.deck.fg; visible: !!tab.curveData }

  // ---------- Curve ----------
  Seg {
    width: parent.width
    visible: tab.fans.length > 1
    bordered: false
    options: tab.fans.map(function(f) {
      var rpm = tab.liveFans[f]
      return { value: f, icon: "󰈐", label: f.toUpperCase() + (rpm !== null && rpm !== undefined ? " · " + Model.rpm(rpm) : "") }
    })
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
      spacing: Style.space(6)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "󰔏"
        color: tab.deck.fg
        opacity: 0.6
        font.family: tab.deck.fontFamily
        font.pixelSize: Style.font.body
      }

      NumberField {
        id: tempField
        anchors.verticalCenter: parent.verticalCenter
        fieldWidth: Style.space(66)
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
        text: "°C  󰈐"
        color: tab.deck.fg
        opacity: 0.6
        font.family: tab.deck.fontFamily
        font.pixelSize: Style.font.body
      }

      NumberField {
        anchors.verticalCenter: parent.verticalCenter
        fieldWidth: Style.space(66)
        fontSize: Style.font.bodySmall
        from: 0
        to: 100
        stepSize: 1
        value: pointEditor.point.p
        foreground: tab.deck.fg
        fontFamily: tab.deck.fontFamily
        onModified: function(v) { pointEditor.queue(pointEditor.point.t, v) }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "%"
        color: tab.deck.fg
        opacity: 0.6
        font.family: tab.deck.fontFamily
        font.pixelSize: Style.font.body
      }
    }
  }

  Caption {
    width: parent.width
    visible: !!tab.curveData
    text: tab.custom ? "Drag a bar, or pick a point with the arrows and type exact values. Scroll a temperature to nudge it."
                     : "Turn on the custom curve to edit it."
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
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

  PanelSeparator { foreground: tab.deck.fg; visible: !!tab.curveData }

  // ---------- Presets ----------
  SectionHeader {
    icon: "󱐋"
    title: "PRESETS"
    detail: "BOTH FANS"
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    visible: !!tab.curveData
  }

  Seg {
    width: parent.width
    visible: !!tab.curveData
    options: [
      { value: "silent", label: "Silent", icon: "󰌪", hint: "Fans off until about 70 °C" },
      { value: "stock", label: "Stock", icon: "󰈐", hint: "Close to the firmware curve" },
      { value: "cool", label: "Cool", icon: "󰔏", hint: "Spins up early" },
      { value: "max", label: "Max", icon: "󰓅", hint: "Full speed" },
      { value: "reset", label: "Reset", icon: "󰑓", hint: "Firmware curve, custom off" }
    ]
    value: ""
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onPicked: function(v) {
      if (v === "reset") tab.service.resetFans(tab.mode)
      else tab.service.setFanPreset(tab.mode, v)
    }
  }
}
