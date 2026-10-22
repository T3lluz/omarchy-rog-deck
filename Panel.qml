import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model
import "components"

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
  readonly property string gpuAsk: service ? service.gpuAsk : ""

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

  // Tabs appear only for hardware the laptop has.
  readonly property var tabs: {
    var t = [{ value: "main", label: "Main", icon: "󰕮" }]
    if (status && status.keyboard && status.keyboard.brightness !== null) t.push({ value: "lighting", label: "Keys", icon: "󰌌", hint: "Keyboard lighting" })
    if (status && status.anime) t.push({ value: "anime", label: "AniMe", icon: "󱗼", hint: "AniMe Matrix" })
    if (status && status.fans && (status.fans.cpu !== null || status.fans.gpu !== null)) t.push({ value: "fans", label: "Fans", icon: "󰈐" })
    t.push({ value: "system", label: "System", icon: "󰒓" })
    return t
  }
  readonly property string currentTab: {
    var want = service ? service.panelTab : "main"
    for (var i = 0; i < tabs.length; i++) if (tabs[i].value === want) return want
    return "main"
  }

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

  function selectTab(step) {
    var index = 0
    for (var i = 0; i < tabs.length; i++) if (tabs[i].value === currentTab) index = i
    var next = (index + step + tabs.length) % tabs.length
    if (service) service.panelTab = tabs[next].value
    flick.contentY = 0
  }

  function askGpuMode(mode) {
    if (service) service.askGpuMode(mode)
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
    // Closing the panel drops an unanswered restart prompt.
    if (!opened) {
      if (service) service.gpuAsk = ""
      return
    }
    cursorActive = false
    flick.contentY = 0
    for (var i = 0; i < profiles.length; i++) if (profiles[i].key === activeProfile) profileCursor = i
    if (service) service.refreshFans()
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
    tooltipText: root.opened ? "" : Model.tooltip(root.status && root.service ? root.service.withActive() : null)
    onPressed: function(b) {
      if (b === Qt.MiddleButton) { if (root.service) root.service.toggleKbd() }
      else root.toggle()
    }
    onWheelMoved: function(delta) { if (root.service) root.service.stepProfile(delta) }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    // The Flickable is inset by flickMargin on every side; ask for that much
    // extra so the last row of a tab is never clipped.
    readonly property real flickMargin: Style.space(4)
    contentWidth: panel.fittedContentWidth(Style.space(420) + flickMargin * 2)
    contentHeight: panel.fittedContentHeight(column.implicitHeight + flickMargin * 2)

    Flickable {
      id: flick
      anchors.fill: parent
      anchors.margins: panel.flickMargin
      contentHeight: column.implicitHeight
      clip: true
      flickableDirection: Flickable.VerticalFlick
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: column
        width: flick.width
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

        Seg {
          width: parent.width
          visible: root.ready
          bordered: false
          options: root.tabs
          value: root.currentTab
          foreground: root.fg
          fontFamily: root.fontFamily
          onPicked: function(v) {
            if (root.service) root.service.panelTab = v
            flick.contentY = 0
          }
        }

        PanelSeparator { foreground: root.fg; visible: root.ready }

        // Every tab is built up front and shown by visibility: a Loader can
        // take a few frames to build, which flashed a blank tab on open.
        MainTab { width: parent.width; deck: root; visible: root.ready && root.currentTab === "main" }
        LightingTab { width: parent.width; deck: root; visible: root.ready && root.currentTab === "lighting" }
        AnimeTab { width: parent.width; deck: root; visible: root.ready && root.currentTab === "anime" }
        FansTab { width: parent.width; deck: root; visible: root.ready && root.currentTab === "fans" }
        SystemTab { width: parent.width; deck: root; visible: root.ready && root.currentTab === "system" }

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

    ConfirmDialog {
      id: gpuConfirm
      anchors.fill: parent
      z: 10
      opened: root.gpuAsk !== ""
      message: "Switch to " + Model.gpuModeInfo(root.gpuAsk).label + " GPU mode? The laptop restarts now to finish, closing open windows."
      confirmText: "Restart"
      foreground: root.fg
      fontFamily: root.fontFamily
      // Start on Cancel: Enter alone should never reboot.
      onOpenedChanged: if (opened) selectedIndex = 0
      onCanceled: root.service.gpuAsk = ""
      onConfirmed: {
        root.service.setGpuMode(root.gpuAsk, true)
        root.service.gpuAsk = ""
      }
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (gpuConfirm.opened) {
          if (dx !== 0) gpuConfirm.selectedIndex = gpuConfirm.selectedIndex === 0 ? 1 : 0
          return
        }
        if (dx !== 0) {
          // Left/right walks the power modes on Main, the tabs elsewhere.
          if (root.currentTab === "main") {
            if (!root.cursorActive) { root.cursorActive = true; return }
            root.moveProfileCursor(dx)
          } else {
            root.selectTab(dx)
          }
        } else if (dy !== 0) {
          flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY - dy * 40))
        }
      }
      onActivateRequested: {
        if (gpuConfirm.opened) {
          if (gpuConfirm.selectedIndex === 0) gpuConfirm.canceled()
          else gpuConfirm.confirmed()
          return
        }
        if (root.currentTab === "main" && root.cursorActive && root.profiles.length > 0 && root.service)
          root.service.setProfile(root.profiles[root.profileCursor].key)
      }
      onCloseRequested: {
        if (gpuConfirm.opened) gpuConfirm.canceled()
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
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
}
