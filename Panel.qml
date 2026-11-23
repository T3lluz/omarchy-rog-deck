import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model
import "components"
import "components/Rooms.js" as Rooms

// ROG Deck in the bar, in the Rooms look Batteries and Sonus share. The bar
// item is the power mode in pixels (a leaf, then a dial from upright to
// fast), plus the readings picked for the bar in the pixel type. Its panel is one page of
// rooms, each tinted in a tone of its own from the theme's palette: the power
// mode, the CPU and GPU, the fans, the battery, the graphics, the screen, the
// keyboard light and the AniMe Matrix.
// A click opens a room to its details; the gear swaps the rooms for the
// settings. All state lives in Service.qml; this file only draws it and
// forwards clicks, so every monitor's widget agrees.
Panel {
  id: root
  moduleName: "io.github.t3lluz.rog-deck"
  // The service owns the IPC target, so the panel must not register one.
  manageIpc: false

  property var service: null
  readonly property var status: service ? service.status : null
  readonly property string activeProfile: service ? service.activeProfile : ""
  readonly property var profiles: Model.profileChoices(status)
  readonly property var activeInfo: Model.profileInfo(activeProfile)
  readonly property bool ready: !!status && status.asusd === true
  readonly property string gpuAsk: service ? service.gpuAsk : ""

  readonly property color fg: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(fg, 1.5)
  readonly property color accent: Commons.Color.accent
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  // Every word ROG Deck draws is in Monocraft, a pixel font that matches the
  // pixel icons and figures. It ships in assets/fonts, so it needs no system
  // install. The bold face is loaded too, so bold text uses Monocraft's own
  // bold instead of a smeared synthetic one. Until it loads, or if it can't,
  // text falls back to the bar's font.
  FontLoader { id: monocraft; source: Qt.resolvedUrl("assets/fonts/Monocraft.ttf") }
  FontLoader { id: monocraftBold; source: Qt.resolvedUrl("assets/fonts/Monocraft-Bold.ttf") }
  readonly property string fontFamily: monocraft.status === FontLoader.Ready ? monocraft.name
    : bar ? bar.fontFamily : Style.font.family
  // The block-face figures (BigFigure) take their cell size from a font's
  // digits and line height. They keep the bar's font for that, so the
  // figures stay the size they were drawn for; Monocraft's wider, shorter
  // cells squashed them.
  readonly property string gridFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool vertical: bar ? bar.vertical : false

  // Rooms are padded 10 and joined by 3, as in Batteries and Sonus; their
  // icons are pixel art at about 20 px (24 device pixels on a 1.25 scale),
  // and names and meters start past that column. Wider than Omarchy's 380 so
  // two rooms share a row with their numbers whole, and a quarter room holds
  // its name and a three-digit figure.
  readonly property real panelWidth: Style.space(520)
  readonly property real roomGap: Style.space(3)
  readonly property real roomPad: Style.space(10)
  readonly property real iconColumn: Math.round(Style.font.heading * 1.25)
  readonly property real textInset: iconColumn + Style.space(10)

  // ---- settings ---------------------------------------------------------------

  // Settings come from shell.json itself rather than the bar's copy, so
  // every monitor agrees after a reload (WidgetSettings.qml).
  function setting(name, fallback) { return prefs.get(name, fallback) }
  function persistSettings(values) { prefs.save(values) }

  function setBarStat(key, on) {
    var values = {}
    values[key] = on
    persistSettings(values)
  }

  // The stats picked for the bar, in bar order. With none, the bar shows
  // only the mode's icon.
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
  readonly property bool watching: opened || barLive
  property bool countedWatch: false

  WidgetSettings {
    id: prefs
    moduleName: root.moduleName
    injected: root.settings
    shell: root.bar ? root.bar.shell : null
  }

  // ---- tones ------------------------------------------------------------------

  // The theme's terminal colours, read from its colors.toml whenever the
  // panel opens, so a theme switch shows on the next open.
  property var palette: ({})

  FileView {
    id: paletteFile
    path: Commons.Color.currentThemePath + "/colors.toml"
    blockLoading: false
    printErrors: false
    onLoaded: root.palette = Rooms.parsePalette(text())
  }

  // A room's colour (Rooms.roomToneHex): the theme's colour of that name, or
  // the tone's own hue where the theme's is a grey, softened toward the text
  // colour. The text colour where it would still read too faint. Only the
  // panel and the hover card take these; the bar keeps the bar's colours.
  function toneOf(room) {
    var c = Qt.color(Rooms.roomToneHex(Model.roomTone(room), palette, String(fg)))
    return Rooms.contrast(c, Commons.Color.background) >= 2.6 ? c : fg
  }

  // Hot and low: the theme's urgent colour where it reads on the background,
  // else the text colour. Never colour alone; a mark goes with it.
  readonly property color lowTone: Rooms.contrast(urgent, Commons.Color.background) >= 3.5 ? urgent : fg

  // ---- motion -----------------------------------------------------------------

  // Goes up each time the panel opens: rooms rise in, meters fill, lines
  // decode and icons act themselves out, once.
  property int entry: 0

  // One clock for everything that moves on its own, ticking only while a
  // ripple still runs.
  readonly property real clockBase: Date.now()
  property real clock: 0
  property real awakeUntil: 0

  function wake(ms) {
    clock = Date.now() - clockBase
    awakeUntil = Math.max(awakeUntil, clock + ms)
  }

  Timer {
    interval: 70
    repeat: true
    running: root.opened && !Style.reduceMotion && root.clock < root.awakeUntil
    onTriggered: root.clock = Date.now() - root.clockBase
  }

  // Switching between the rooms, the fan curves and the settings slides the
  // new page in from the side it lives on, and the gear turns (or the arrow
  // nudges) as it does.
  property string view: "rooms"
  readonly property var pageOrder: ["rooms", "fans", "settings"]
  property real pageShift: 0
  property real pageFade: 1
  property real gearTurn: 0

  ParallelAnimation {
    id: pageIn
    NumberAnimation { target: root; property: "pageShift"; to: 0; duration: Style.duration(320); easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "pageFade"; to: 1; duration: Style.duration(220); easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "gearTurn"; to: 0; duration: Style.duration(420); easing.type: Easing.OutCubic }
  }

  function setView(next) {
    var from = view
    if (from === next) return
    view = next
    openRoom = ""
    flick.contentY = 0
    if (opened && !Style.reduceMotion) {
      var ahead = pageOrder.indexOf(next) > pageOrder.indexOf(from)
      pageShift = Style.space(ahead ? 18 : -18)
      pageFade = 0
      gearTurn = next === "rooms" ? -1 : 1
      pageIn.restart()
    }
  }

  // ---- rooms ------------------------------------------------------------------

  // One room open at a time.
  property string openRoom: ""

  function toggleRoom(key) {
    openRoom = openRoom === key ? "" : key
  }

  // Which rooms this laptop has, so a row with one room gives it the whole
  // width.
  readonly property bool hasBattery: !!status && !!status.battery && status.battery.percent !== null && status.battery.percent !== undefined
  readonly property bool hasHeat: !!status && !!status.temps && (status.temps.cpu !== null && status.temps.cpu !== undefined)
  readonly property bool hasFans: !!status && !!status.fans && (status.fans.cpu !== null || status.fans.gpu !== null)
  readonly property bool hasDisplay: !!status && !!status.display
  readonly property bool hasGraphics: !!status && (!!status.gpu || !!status.dgpu)
  readonly property bool hasKeyboard: !!status && !!status.keyboard && status.keyboard.brightness !== null && status.keyboard.brightness !== undefined
  readonly property bool hasAnime: !!status && !!status.anime

  // ---- the hero's prompt -------------------------------------------------------

  // The prompt under the title: what needs attention holds still, an open
  // room says what it holds, and otherwise it takes turns with the facts, a
  // new one every 2.8 s, each typed out by the hero.
  property int phraseIndex: 0

  readonly property var heroPhrases: Model.heroPhrases(!status ? null : {
    ready: ready,
    profile: activeProfile,
    ac: !!service && !service.onBattery,
    temps: status.temps,
    fans: status.fans,
    dgpu: status.dgpu,
    gpuMode: status.gpu ? status.gpu.mode : "",
    battery: status.battery,
    refresh: status.display ? status.display.refresh : null,
    model: status.model
  })

  readonly property string heroLine: {
    if (!service || !status) return "Reading the laptop"
    if (!ready) return "asusd is not running"
    if (gpuAsk !== "") return "Restart to switch to " + Model.gpuModeInfo(gpuAsk).label + "?"
    var gpu = status.gpu
    var next = gpu ? String(service.pick("gpu.next", gpu.next)) : ""
    if (gpu && next !== gpu.mode) return "Restart to finish switching to " + Model.gpuModeInfo(next).label
    if (openRoom !== "") return Model.roomLine(openRoom, activeProfile)
    var list = heroPhrases
    return list[phraseIndex % list.length]
  }

  // Which line the prompt is on, apart from the numbers in it, so a refresh
  // swaps a reading in place and only a new line types itself out.
  readonly property string heroKey: {
    if (!service || !status) return "reading"
    if (!ready) return "asusd"
    if (gpuAsk !== "") return "ask:" + gpuAsk
    var gpu = status.gpu
    if (gpu && String(service.pick("gpu.next", gpu.next)) !== gpu.mode) return "restart"
    if (openRoom !== "") return "room:" + openRoom
    return "phrase:" + (phraseIndex % Math.max(1, heroPhrases.length))
  }

  Timer {
    interval: 2800
    running: root.opened && root.view === "rooms" && root.openRoom === "" && root.heroPhrases.length > 1
    repeat: true
    onTriggered: root.phraseIndex = root.phraseIndex + 1
  }

  // ---- banners ----------------------------------------------------------------

  // Before the panel is ready only an error is worth a banner, and a missing
  // asusd is the one that explains the empty panel.
  readonly property var notices: {
    if (!service) return []
    var list = service.notices.filter(function(n) { return ready || n.key === "error" })
    if (status && !ready) list.unshift({ key: "asusd", tone: "urgent", icon: "󰀦",
      text: "asusd is not running, so power modes, lighting and fans are out of reach. Start it with: sudo systemctl start asusd" })
    return list
  }

  function noticeAction(notice) {
    if (!service) return
    if (notice.action === "restart") {
      var gpu = status ? status.gpu : null
      if (gpu) service.askGpuMode(String(service.pick("gpu.next", gpu.next)))
    } else if (notice.action === "update") {
      service.applyUpdate()
    } else if (notice.action === "integrated") {
      service.askGpuMode("integrated")
    } else if (notice.action === "power-setup") {
      // Full speed wants the helper on models without a CPU limit table too.
      service.ensureHelper(service.settings.fullSpeed.enabled && service.speedCapable)
    }
  }

  function askGpuMode(mode) {
    if (service) service.askGpuMode(mode)
  }

  // ---- keyboard ----------------------------------------------------------------

  // Left and right walk the power modes (the first press lights the cursor),
  // Enter picks one. Up and down scroll.
  property bool cursorActive: false
  property int profileCursor: 0

  function moveProfileCursor(delta) {
    if (profiles.length === 0) return
    profileCursor = Math.max(0, Math.min(profiles.length - 1, profileCursor + delta))
  }

  // ---- service ------------------------------------------------------------------

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

  // An IPC call can ask for a room or a page before the panel opens.
  function takeRequest() {
    if (!service || service.requestedRoom === "") return
    var want = service.requestedRoom
    service.requestedRoom = ""
    if (want === "settings" || want === "fans-curve") setView(want === "settings" ? "settings" : "fans")
    else { setView("rooms"); openRoom = want }
  }

  onBarChanged: lookupService()
  onWatchingChanged: syncWatch()
  onServiceChanged: syncWatch()
  Component.onCompleted: lookupService()
  Component.onDestruction: if (countedWatch && service) service.watchers = Math.max(0, service.watchers - 1)

  Connections {
    target: root.service
    function onRequestedRoomChanged() { if (root.opened) root.takeRequest() }
  }

  onOpenedChanged: {
    if (!opened) {
      // Closing the panel drops an unanswered restart prompt.
      if (service) service.gpuAsk = ""
      return
    }
    view = "rooms"
    openRoom = ""
    phraseIndex = 0
    cursorActive = false
    pageIn.stop()
    pageShift = 0
    pageFade = 1
    gearTurn = 0
    flick.contentY = 0
    for (var i = 0; i < profiles.length; i++) if (profiles[i].key === activeProfile) profileCursor = i
    paletteFile.reload()
    if (service) service.refreshFans()
    takeRequest()
    entry++
  }

  // The service may load after the bar does.
  Timer {
    interval: 1000
    repeat: true
    running: !root.service
    onTriggered: root.lookupService()
  }

  // ---- bar ------------------------------------------------------------------------

  // Everything on whole device pixels, never scaled. The mode's icon takes the
  // largest sharp size that is not bigger than the shell's own icons (its
  // icon size, with pixel art's two units clear around the 24): twelve device
  // pixels on a 1.25 scale, twenty-four on a 2. The figures stand as tall as
  // the bar's digits.
  readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
  readonly property int iconUnit: Math.max(1, Math.floor(Style.bar.iconSize * 24 / 20 * dpr / 12))
  readonly property int pixelUnit: Math.max(1, Math.round(button.fontSize * 0.72 * dpr / 5))
  readonly property color barFg: bar ? bar.barForeground : Commons.Color.foreground

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    hasVisualContent: true
    dimmed: !root.ready
    // The hover card below takes the place of the plain tooltip, which stays
    // only to say why there is nothing to show.
    tooltipText: root.opened || root.hoverRows.length > 0 ? "" : Model.tooltip(root.status && root.service ? root.service.withActive() : null)
    fixedWidth: root.vertical ? -1 : (root.barParts.length > 0 ? content.implicitWidth + scaledHorizontalMargin * 2 : Style.bar.iconSlot)
    fixedHeight: root.vertical ? Style.bar.iconSlot : -1
    onPressed: function(b) {
      if (b === Qt.MiddleButton) { if (root.service) root.service.toggleKbd() }
      else if (b === Qt.RightButton) {
        if (root.opened && root.view === "settings") root.close()
        else {
          if (!root.opened) root.open()
          root.setView("settings")
        }
      } else root.toggle()
    }
    onWheelMoved: function(delta) { if (root.service) root.service.stepProfile(delta) }

    Row {
      id: content
      anchors.centerIn: parent
      spacing: Style.space(5)

      // The mode's icon: scrolling swings the dial's needle.
      PixelIcon {
        anchors.verticalCenter: parent.verticalCenter
        name: root.activeInfo.pixel
        unit: root.iconUnit
        color: root.barFg
      }

      // One item per stat: its pixel icon, then the figure in the pixel type,
      // or a word in the bar's own font.
      Repeater {
        model: root.barParts

        Row {
          required property var modelData
          readonly property color ink: modelData.hot ? root.urgent : root.barFg
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(3)

          PixelIcon {
            visible: parent.modelData.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: parent.modelData.icon
            unit: root.iconUnit
            color: parent.ink
          }

          PixelText {
            visible: parent.modelData.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: parent.modelData.text
            unit: root.pixelUnit
            color: parent.ink
          }

          Text {
            visible: parent.modelData.word !== ""
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: parent.modelData.word
            color: parent.ink
            font.family: root.fontFamily
            font.pixelSize: button.fontSize
            renderType: Text.NativeRendering
          }
        }
      }
    }
  }

  // ---- hover card -------------------------------------------------------------------

  // After the shell's tooltip delay, gone the moment the pointer leaves or
  // the panel opens.
  readonly property var hoverRows: Model.hoverRows(status && service ? service.withActive() : null, {
    profile: activeProfile,
    speedHeld: !!status && !!status.speed && status.speed.held && status.speed.epp === "performance" && !!service && !service.onBattery
  })
  readonly property string hoverNote: {
    if (!service) return ""
    var lines = []
    var gpu = status ? status.gpu : null
    var next = gpu ? String(service.pick("gpu.next", gpu.next)) : ""
    if (gpu && next !== gpu.mode) lines.push("Restart to finish switching to " + Model.gpuModeInfo(next).label)
    if (service.updater && service.updater.available) lines.push("Update available")
    return lines.join(" · ")
  }
  readonly property bool cardWanted: button.tooltipHovered && !opened && hoverRows.length > 0
  property bool cardShown: false
  onCardWantedChanged: if (!cardWanted) cardShown = false

  Timer {
    interval: 400
    running: root.cardWanted && !root.cardShown
    onTriggered: {
      paletteFile.reload()
      root.cardShown = true
    }
  }

  HoverCard {
    target: button
    bar: root.bar
    shown: root.cardShown
    rows: root.hoverRows
    note: root.hoverNote
    palette: root.palette
    unit: root.pixelUnit
    fontFamily: root.fontFamily
  }

  // ---- panel -------------------------------------------------------------------------

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    // The Flickable is inset on every side; ask for that much extra so the
    // last row is never clipped.
    readonly property real flickMargin: Style.space(4)
    contentWidth: panel.fittedContentWidth(root.panelWidth + flickMargin * 2)
    contentHeight: panel.fittedContentHeight(pages.implicitHeight + flickMargin * 2)

    Flickable {
      id: flick
      anchors.fill: parent
      anchors.margins: panel.flickMargin
      contentHeight: pages.implicitHeight
      clip: true
      flickableDirection: Flickable.VerticalFlick
      boundsBehavior: Flickable.StopAtBounds

      Item {
        id: pages
        width: flick.width
        implicitHeight: root.view === "settings" ? settingsPage.implicitHeight
          : root.view === "fans" ? fansPage.implicitHeight : roomsColumn.implicitHeight

        // ---- rooms ----------------------------------------------------------
        RoomsPage {
          id: roomsColumn
          host: root
          width: parent.width
          visible: root.view === "rooms"
          opacity: root.pageFade
          transform: Translate { x: root.view === "rooms" ? root.pageShift : 0 }
        }

        // ---- fan curves and settings ------------------------------------------
        FansPage {
          id: fansPage
          host: root
          width: parent.width
          visible: root.view === "fans"
          opacity: root.pageFade
          transform: Translate { x: root.view === "fans" ? root.pageShift : 0 }
        }

        SettingsPage {
          id: settingsPage
          host: root
          width: parent.width
          visible: root.view === "settings"
          opacity: root.pageFade
          transform: Translate { x: root.view === "settings" ? root.pageShift : 0 }
        }
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
        if (dx !== 0 && root.view === "rooms") {
          if (!root.cursorActive) { root.cursorActive = true; return }
          root.moveProfileCursor(dx)
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
        if (root.view === "rooms" && root.cursorActive && root.profiles.length > 0 && root.service)
          root.service.setProfile(root.profiles[root.profileCursor].key)
      }
      onCloseRequested: {
        if (gpuConfirm.opened) gpuConfirm.canceled()
        else if (root.openRoom !== "") root.openRoom = ""
        else if (root.view !== "rooms") root.setView("rooms")
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        var key = t.toLowerCase()
        if (key === "s" || key === ",") root.setView(root.view === "settings" ? "rooms" : "settings")
      }
    }
  }
}
