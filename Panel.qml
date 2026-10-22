import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Bar entry and control panel. All state lives in Service.qml; this file
// only draws it and forwards clicks, so every monitor's widget agrees.
Panel {
  id: root
  moduleName: "io.github.t3lluz.rog-deck"
  // The service owns the IPC target, so the panel must not register one.
  manageIpc: false

  property var service: null
  property bool cursorActive: false
  property int profileCursor: 0

  readonly property var status: service ? service.status : null
  readonly property string activeProfile: service ? service.activeProfile : ""
  readonly property var profiles: Model.profileChoices(status)
  readonly property var activeInfo: Model.profileInfo(activeProfile)
  readonly property bool ready: !!status && status.asusd === true

  readonly property bool barTemps: setting("barTemps", false) === true
  readonly property bool barFans: setting("barFans", false) === true
  readonly property bool barLive: (barTemps || barFans) && !vertical
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property bool watching: opened || barLive
  property bool countedWatch: false

  readonly property color fg: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(fg, 1.55)
  readonly property color accent: Commons.Color.accent
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string barText: {
    var parts = []
    if (barLive && status) {
      if (barTemps) parts.push(Model.temperature(status.temps ? status.temps.cpu : null))
      if (barFans) parts.push("󰈐 " + Model.rpm(Model.maxFan(status)))
    }
    parts.push(activeInfo.icon)
    return parts.join("  ")
  }

  function heatColor(celsius) {
    var level = Model.heat(celsius)
    if (level === 2) return urgent
    if (level === 1) return Qt.tint(fg, Qt.rgba(urgent.r, urgent.g, urgent.b, 0.45))
    return fg
  }

  function lookupService() {
    if (service) return
    var shell = bar ? bar.shell : null
    if (shell && typeof shell.serviceFor === "function") service = shell.serviceFor(moduleName)
  }

  function syncWatch() {
    var want = watching && !!service
    if (want === countedWatch) return
    countedWatch = want
    service.watchers = Math.max(0, service.watchers + (want ? 1 : -1))
    if (want) service.refresh()
  }

  function moveProfileCursor(delta) {
    if (profiles.length === 0) return
    profileCursor = Math.max(0, Math.min(profiles.length - 1, profileCursor + delta))
  }

  onBarChanged: lookupService()
  onWatchingChanged: syncWatch()
  onServiceChanged: syncWatch()
  Component.onCompleted: lookupService()
  Component.onDestruction: if (countedWatch && service) service.watchers = Math.max(0, service.watchers - 1)

  onOpenedChanged: {
    if (!opened) return
    cursorActive = false
    for (var i = 0; i < profiles.length; i++) if (profiles[i].key === activeProfile) profileCursor = i
  }

  // The service may load after the bar does.
  Timer {
    interval: 1000
    repeat: true
    running: !root.service
    onTriggered: root.lookupService()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barText
    slotSize: root.barLive ? Math.max(Style.bar.iconSlot, glyphPaintedWidth + Style.space(14)) : Style.bar.iconSlot
    dimmed: !root.ready
    tooltipText: root.opened ? "" : Model.tooltip(root.status ? root.service.withActive() : null)
    onPressed: function(b) { root.toggle() }
    onWheelMoved: function(delta) { if (root.service) root.service.stepProfile(delta) }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveProfileCursor(dx !== 0 ? dx : dy)
      }
      onActivateRequested: {
        if (root.cursorActive && root.profiles.length > 0 && root.service)
          root.service.setProfile(root.profiles[root.profileCursor].key)
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Hero: mode glyph · model · temperatures ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: root.activeInfo.icon
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroTemps.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: root.status && root.status.model ? String(root.status.model).replace(/_.*$/, "") : "ROG Deck"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: {
                if (!root.service || !root.status) return "READING THE LAPTOP…"
                if (!root.ready) return "ASUSD IS NOT RUNNING"
                return (root.activeInfo.label + " mode · " + (root.status.ac ? "plugged in" : "on battery")).toUpperCase()
              }
              color: root.ready || !root.status ? root.dim : root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Row {
            id: heroTemps
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(14)
            visible: root.ready

            TempReading { label: "CPU"; value: root.status && root.status.temps ? root.status.temps.cpu : null }
            TempReading {
              label: "GPU"
              value: root.status && root.status.temps ? root.status.temps.gpu : null
              visible: value !== null && value !== undefined
            }
          }
        }

        PanelSeparator { foreground: root.fg; visible: root.ready }

        // ---------- Power mode ----------
        Column {
          width: parent.width
          spacing: Style.space(10)
          visible: root.ready && root.profiles.length > 0

          PanelSectionHeader {
            text: "POWER MODE"
            foreground: root.fg
            fontFamily: root.fontFamily
          }

          Row {
            id: profileRow
            width: parent.width
            spacing: Style.space(6)

            readonly property real cellWidth: root.profiles.length > 0
              ? (width - spacing * (root.profiles.length - 1)) / root.profiles.length : 0

            Repeater {
              model: root.profiles

              Button {
                required property var modelData
                required property int index
                width: profileRow.cellWidth
                iconText: modelData.icon
                iconSize: Style.font.title
                text: modelData.label
                tooltipText: modelData.hint
                fontSize: Style.font.bodySmall
                foreground: root.fg
                fontFamily: root.fontFamily
                verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                bordered: true
                active: root.activeProfile === modelData.key
                hasCursor: root.cursorActive && root.profileCursor === index
                onClicked: if (root.service) root.service.setProfile(modelData.key)
                onHovered: function(h) {
                  if (!h) return
                  root.cursorActive = true
                  root.profileCursor = index
                }
              }
            }
          }
        }

        // ---------- Live readings ----------
        Grid {
          width: parent.width
          columns: 2
          columnSpacing: Style.space(20)
          rowSpacing: Style.spacing.labelGap
          visible: root.ready

          readonly property real cellWidth: (width - columnSpacing) / 2

          InfoPair {
            width: parent.cellWidth
            label: "CPU fan"
            value: root.status && root.status.fans ? Model.rpm(root.status.fans.cpu) + " rpm" : "—"
          }
          InfoPair {
            width: parent.cellWidth
            label: "GPU fan"
            value: root.status && root.status.fans ? Model.rpm(root.status.fans.gpu) + " rpm" : "—"
          }
          InfoPair {
            width: parent.cellWidth
            label: "Battery"
            value: root.status ? (Model.batteryLine(root.status.battery, root.status.ac) || "—") : "—"
          }
          InfoPair {
            width: parent.cellWidth
            label: "Dedicated GPU"
            value: {
              if (!root.status) return "—"
              var text = Model.dgpuLabel(root.status.dgpu)
              var w = root.status.watts ? root.status.watts.dgpu : null
              return w ? text + " · " + Model.watts(w) : text
            }
          }
          InfoPair {
            width: parent.cellWidth
            label: "Charge limit"
            value: root.status && root.status.battery && root.status.battery.limit ? root.status.battery.limit + "%" : "—"
            visible: !!(root.status && root.status.battery)
          }
          InfoPair {
            width: parent.cellWidth
            label: "Screen"
            value: root.status && root.status.display ? root.status.display.refresh + " Hz" : "—"
            visible: !!(root.status && root.status.display)
          }
        }

        Text {
          width: parent.width
          visible: !!root.service && root.service.lastError !== ""
          text: root.service ? root.service.lastError : ""
          color: root.urgent
          wrapMode: Text.Wrap
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }

  component TempReading: Column {
    property string label: ""
    property var value: null
    spacing: 0

    Text {
      anchors.right: parent.right
      textFormat: Text.PlainText
      text: Model.temperature(parent.value)
      color: root.heatColor(parent.value)
      font.family: root.fontFamily
      font.pixelSize: Style.font.heading
      font.bold: true
      Behavior on color { ColorAnimation { duration: 300 } }
    }

    Text {
      anchors.right: parent.right
      textFormat: Text.PlainText
      text: parent.label
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1.2
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""
    spacing: Style.space(8)

    Text {
      id: pairLabel
      textFormat: Text.PlainText
      text: parent.label
      color: root.fg
      opacity: 0.6
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Item { width: Math.max(0, parent.width - pairLabel.implicitWidth - pairValue.implicitWidth - parent.spacing * 2); height: 1 }
    Text {
      id: pairValue
      textFormat: Text.PlainText
      text: parent.value
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }
}
