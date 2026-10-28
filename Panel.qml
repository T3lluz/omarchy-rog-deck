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
  // Before the panel is ready only an error is worth a banner, and a missing
  // asusd is the one that explains the empty panel.
  readonly property var notices: {
    if (!service) return []
    var list = service.notices.filter(function(n) { return ready || n.key === "error" })
    if (status && !ready) list.unshift({ key: "asusd", tone: "urgent", icon: "󰀦",
      text: "asusd is not running, so power modes, lighting and fans are out of reach. Start it with: sudo systemctl start asusd" })
    return list
  }

  readonly property var status: service ? service.status : null
  readonly property string activeProfile: service ? service.activeProfile : ""
  readonly property var profiles: Model.profileChoices(status)
  readonly property var activeInfo: Model.profileInfo(activeProfile)
  readonly property bool ready: !!status && status.asusd === true

  // The stats picked for the bar, in bar order. Picked in the System tab or
  // the widget settings; with none, the bar shows only the mode icon.
  readonly property var barStats: {
    var stats = []
    for (var i = 0; i < Model.BAR_STATS.length; i++) {
      var option = Model.BAR_STATS[i]
      if (setting(option.key, option.fallback) === true) stats.push(option.stat)
    }
    return stats
  }
  readonly property bool barLive: barStats.length > 0 && !vertical
  readonly property var barParts: barLive ? Model.barParts(status && service ? service.withActive() : null, barStats) : []
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

  // Settings come from shell.json itself rather than the bar's copy, so
  // every monitor agrees after a reload (WidgetSettings.qml).
  function setting(name, fallback) { return prefs.get(name, fallback) }
  function persistSettings(values) { prefs.save(values) }

  function setBarStat(key, on) {
    var values = {}
    values[key] = on
    persistSettings(values)
  }

  // `base` is the colour for a cool reading: the panel's or the bar's.
  function heatColor(celsius, base) {
    var cool = base === undefined ? fg : base
    var level = Model.heat(celsius)
    if (level === 2) return urgent
    if (level === 1) return Qt.tint(cool, Qt.rgba(urgent.r, urgent.g, urgent.b, 0.45))
    return cool
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

  function noticeAction(notice) {
    if (!service) return
    if (notice.action === "restart") {
      var gpu = status ? status.gpu : null
      if (gpu) service.askGpuMode(String(service.pick("gpu.next", gpu.next)))
    } else if (notice.action === "update") {
      service.applyUpdate()
    }
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

  WidgetSettings {
    id: prefs
    moduleName: root.moduleName
    injected: root.settings
    shell: root.bar ? root.bar.shell : null
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

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    hasVisualContent: true
    dimmed: !root.ready
    tooltipText: root.opened ? "" : Model.tooltip(root.status && root.service ? root.service.withActive() : null)
    fixedWidth: root.vertical ? -1 : (root.barParts.length > 0 ? content.implicitWidth + scaledHorizontalMargin * 2 : Style.bar.iconSlot)
    fixedHeight: root.vertical ? Style.bar.iconSlot : -1
    onPressed: function(b) {
      if (b === Qt.MiddleButton) { if (root.service) root.service.toggleKbd() }
      else root.toggle()
    }
    onWheelMoved: function(delta) { if (root.service) root.service.stepProfile(delta) }

    Row {
      id: content
      anchors.centerIn: parent
      spacing: Style.space(6)

      Item {
        anchors.verticalCenter: parent.verticalCenter
        width: Style.bar.iconCanvas
        height: Style.bar.iconCanvas

        OpticalGlyph {
          anchors.fill: parent
          text: root.activeInfo.icon
          fontFamily: button.fontFamily
          fontSize: Style.bar.iconFont
          color: root.barForeground
        }
      }

      // One item per stat so the row spacing, not padding characters,
      // separates them: the same gap as between the icon and the first stat.
      Repeater {
        model: root.barParts

        Text {
          required property var modelData
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: modelData.text
          color: modelData.temp !== null ? root.heatColor(modelData.temp, root.barForeground) : root.barForeground
          font.family: button.fontFamily
          font.pixelSize: button.fontSize
          renderType: Text.NativeRendering
        }
      }
    }
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
        PanelHero {
          width: parent.width
          title: root.status && root.status.model ? String(root.status.model).replace(/_.*$/, "") : "ROG Deck"
          meta: {
            if (!root.service || !root.status) return "Reading the laptop…"
            if (!root.ready) return "asusd is not running"
            return root.activeInfo.label + " mode · " + (root.status.ac ? "plugged in" : "on battery")
          }
          foreground: root.fg
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              textFormat: Text.PlainText
              text: root.activeInfo.icon
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
          trailingControl: Component {
            Row {
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

        // Errors, a GPU switch waiting on a restart, and updates: above every
        // tab, so they can't be missed by staying on another one.
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.notices.length > 0

          Repeater {
            model: root.notices

            Notice {
              required property var modelData
              width: parent.width
              icon: modelData.icon || ""
              text: modelData.text
              tone: modelData.tone || "accent"
              actionLabel: modelData.actionLabel || ""
              busy: !!modelData.busy
              dismissable: !!modelData.dismissable
              foreground: root.fg
              accent: root.accent
              urgent: root.urgent
              fontFamily: root.fontFamily
              onActioned: root.noticeAction(modelData)
              onDismissed: if (root.service) root.service.dismissNotice(modelData)
            }
          }
        }

        // Every tab is built up front and shown by visibility: a Loader can
        // take a few frames to build, which flashed a blank tab on open.
        MainTab { width: parent.width; deck: root; visible: root.ready && root.currentTab === "main" }
        LightingTab { width: parent.width; deck: root; visible: root.ready && root.currentTab === "lighting" }
        AnimeTab { width: parent.width; deck: root; visible: root.ready && root.currentTab === "anime" }
        FansTab { width: parent.width; deck: root; visible: root.ready && root.currentTab === "fans" }
        SystemTab { width: parent.width; deck: root; visible: root.ready && root.currentTab === "system" }

      }
    }

    ConfirmDialog {
      id: gpuConfirm
      anchors.fill: parent
      z: 10
      opened: root.gpuAsk !== ""
      message: Model.gpuConfirmText(root.status ? root.status.gpu : null, root.gpuAsk)
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
          flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + dy * 40))
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
