import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// Omarchy has no settings screen for plugin widgets, so the panel is it. The
// rooms' hero with a way back, then sections from the panel kit, the way the
// other plugins lay out their settings: what the bar shows, the keyboard
// light's finer points, the AniMe Matrix's animations, the firmware's own
// switches, and About and updates. The kit's icons come out as pixel art
// through Glyph.qml.
Column {
  id: page

  required property var host
  readonly property var service: host.service
  readonly property var status: host.status
  readonly property var settings: service ? service.settings : Model.defaultSettings()
  readonly property var kb: status && status.keyboard ? status.keyboard : ({})
  readonly property var light: settings.kbdLight
  readonly property var effects: Model.auraEffects(kb.modes, light.rgb)
  // Until the user picks one here, show what the keyboard is running.
  readonly property string effectKey: {
    if (light.managed) return light.effect
    var running = Model.auraEffectByMode(service ? service.pick("kbd.mode", kb.mode) : kb.mode)
    return running ? running.key : "static"
  }
  readonly property var effect: Model.auraEffect(effectKey)
  readonly property var ledPower: kb.power || ({ boot: true, awake: true, sleep: true, shutdown: true })
  readonly property var anime: status && status.anime ? status.anime : null
  readonly property var builtins: anime && anime.builtins ? anime.builtins : ({})
  readonly property var armoury: status && status.armoury ? status.armoury : ({})
  readonly property var updater: service ? service.updater : null

  function armouryOn(name) {
    var attr = armoury[name]
    return attr && service ? Number(service.pick("armoury." + name, attr.value)) === 1 : false
  }

  spacing: Style.space(12)

  // Have an answer ready the first time the page is opened.
  onVisibleChanged: if (visible && updater && !updater.check && !updater.checking) updater.checkNow()

  HeroBlock {
    width: parent.width
    host: page.host
    icon: "fire"
    iconColor: page.host.toneOf("mark")
    markSize: Math.round(Style.font.title * 1.5)
    title: "Settings"
    line: "Changes save as you make them"
    keepLines: 1

    PixelButton {
      icon: "arrow-left"
      nudge: Math.round(page.host.gearTurn * 2)
      tooltipText: "Back to the rooms (esc)"
      foreground: page.host.fg
      fontFamily: page.host.fontFamily
      onClicked: page.host.setView("rooms")
    }
  }

  PanelSeparator { foreground: page.host.fg }

  // ---------- Bar ----------
  SectionHeader {
    icon: "󰍜"
    title: "SHOW IN THE BAR"
    detail: page.host.barStats.length === 0 ? "ICON ONLY" : page.host.barStats.length + " SHOWN"
    foreground: page.host.fg
    fontFamily: page.host.fontFamily
  }

  Grid {
    id: barGrid
    width: parent.width
    columns: 2
    columnSpacing: Style.space(8)
    rowSpacing: Style.space(8)

    readonly property real tileWidth: (width - columnSpacing) / 2

    Repeater {
      model: Model.BAR_STATS

      ToggleTile {
        required property var modelData
        readonly property bool on: page.host.setting(modelData.key, modelData.fallback) === true
        width: barGrid.tileWidth
        icon: modelData.icon
        label: modelData.label
        hint: modelData.hint || ""
        checked: on
        foreground: page.host.fg
        accent: page.host.accent
        fontFamily: page.host.fontFamily
        onToggled: page.host.setBarStat(modelData.key, !on)
      }
    }
  }

  // ---------- Keyboard light ----------
  PanelSeparator { foreground: page.host.fg; visible: page.kb.brightness !== undefined && page.kb.brightness !== null }

  SectionHeader {
    icon: "󰌌"
    title: "KEYBOARD LIGHT"
    detail: page.effect && page.light.rgb ? page.effect.label.toUpperCase() : ""
    foreground: page.host.fg
    fontFamily: page.host.fontFamily
    visible: page.kb.brightness !== undefined && page.kb.brightness !== null
  }

  Caption {
    width: parent.width
    visible: !!page.kb.power
    text: "Lit during"
    foreground: page.host.fg
    fontFamily: page.host.fontFamily
  }

  Row {
    id: powerRow
    width: parent.width
    spacing: Style.space(6)
    visible: !!page.kb.power

    readonly property var slots: [
      { key: "boot", label: "Startup", icon: "󱓞" }, { key: "awake", label: "Awake", icon: "󰖨" },
      { key: "sleep", label: "Sleep", icon: "󰒲" }, { key: "shutdown", label: "Shutdown", icon: "󰐥" }
    ]
    readonly property real cellWidth: (width - spacing * (slots.length - 1)) / slots.length

    Repeater {
      model: powerRow.slots

      Button {
        required property var modelData
        readonly property bool on: page.service ? !!page.service.pick("kbd.power." + modelData.key, page.ledPower[modelData.key]) : false
        width: powerRow.cellWidth
        text: modelData.label
        tooltipText: (on ? "Lit" : "Dark") + " during " + modelData.label.toLowerCase() + ". Click to change"
        fontSize: Style.font.caption
        foreground: page.host.fg
        fontFamily: page.host.fontFamily
        bordered: true
        active: on
        opacity: on ? 1 : 0.55
        onClicked: page.service.setLedPower(modelData.key, !on)
      }
    }
  }

  SwitchRow {
    width: parent.width
    visible: page.kb.brightness !== undefined && page.kb.brightness !== null
    icon: "󰏘"
    label: "RGB keyboard"
    hint: page.light.rgb ? "Effects and colours are shown" : "Off for a white-only backlight, which stays on Static"
    checked: page.light.rgb
    foreground: page.host.fg
    fontFamily: page.host.fontFamily
    onToggled: page.service.setLighting("rgb", !page.light.rgb)
  }

  Seg {
    width: parent.width
    visible: page.light.rgb && page.effects.length > 1
    options: page.effects.map(function(e) { return { value: e.key, label: e.label } })
    value: page.effectKey
    foreground: page.host.fg
    fontFamily: page.host.fontFamily
    onPicked: function(v) { page.service.setLighting("effect", v) }
  }

  Seg {
    width: parent.width
    visible: page.light.rgb && !!(page.effect && page.effect.speed)
    options: [{ value: "low", label: "Slow" }, { value: "med", label: "Medium" }, { value: "high", label: "Fast" }]
    value: page.light.speed
    foreground: page.host.fg
    fontFamily: page.host.fontFamily
    onPicked: function(v) { page.service.setLighting("speed", v) }
  }

  SwitchRow {
    width: parent.width
    visible: page.light.rgb && !!(page.effect && page.effect.colour)
    icon: "󰸌"
    label: "Follow the Omarchy theme"
    hint: "Uses the theme's keyboard colour and changes with it"
    checked: page.light.followTheme
    foreground: page.host.fg
    fontFamily: page.host.fontFamily
    onToggled: page.service.setLighting("followTheme", !page.light.followTheme)
  }

  Row {
    id: swatches
    width: parent.width
    spacing: Style.space(8)
    visible: page.light.rgb && !page.light.followTheme && !!(page.effect && page.effect.colour)

    readonly property real size: (width - spacing * (Model.SWATCHES.length - 1)) / Model.SWATCHES.length

    Repeater {
      model: Model.SWATCHES

      Rectangle {
        required property string modelData
        width: swatches.size
        height: Style.space(22)
        radius: Style.cornerRadius
        color: "#" + modelData
        border.width: page.light.colour === modelData ? Math.max(2, Style.space(2)) : 0
        border.color: page.host.fg

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: page.service.setLighting("colour", parent.modelData)
        }
      }
    }
  }

  // ---------- AniMe Matrix ----------
  PanelSeparator { foreground: page.host.fg; visible: !!page.anime }

  SectionHeader {
    icon: "󱗼"
    title: "ANIME ANIMATIONS"
    foreground: page.host.fg
    fontFamily: page.host.fontFamily
    visible: !!page.anime
  }

  Repeater {
    model: page.anime ? Model.ANIME_SLOTS : []

    Item {
      required property var modelData
      width: page.width
      height: Math.max(slotSeg.implicitHeight, slotLabel.implicitHeight)

      Glyph {
        id: slotIcon
        anchors.left: parent.left
        anchors.leftMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(22)
        icon: parent.modelData.icon
        size: Style.font.title
        color: page.host.fg
        fontFamily: page.host.fontFamily
      }

      MonoText {
        id: slotLabel
        anchors.left: slotIcon.right
        anchors.leftMargin: Style.space(10)
        anchors.right: slotSeg.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: parent.modelData.label
        color: page.host.fg
        font.family: page.host.fontFamily
        font.pixelSize: Style.font.body
      }

      Seg {
        id: slotSeg
        anchors.right: parent.right
        width: parent.width * 0.6
        options: Model.ANIME_BUILTIN_CHOICES[parent.modelData.slot]
        value: page.service ? page.service.pick("anime." + parent.modelData.slot, page.builtins[parent.modelData.slot]) : ""
        foreground: page.host.fg
        fontFamily: page.host.fontFamily
        onPicked: function(v) { page.service.setAnimeBuiltin(parent.modelData.slot, v) }
      }
    }
  }

  // ---------- Firmware ----------
  PanelSeparator { foreground: page.host.fg; visible: !!page.armoury.boot_sound }

  SectionHeader {
    icon: "󰒓"
    title: "FIRMWARE"
    foreground: page.host.fg
    fontFamily: page.host.fontFamily
    visible: !!page.armoury.boot_sound
  }

  SwitchRow {
    width: parent.width
    visible: !!page.armoury.boot_sound
    icon: "󰕾"
    label: "Boot sound"
    hint: "The chime when the laptop powers on"
    checked: page.armouryOn("boot_sound")
    foreground: page.host.fg
    fontFamily: page.host.fontFamily
    onToggled: page.service.setArmoury("boot_sound", checked ? 0 : 1)
  }

  PanelSeparator { foreground: page.host.fg }

  // ---------- About and updates ----------
  UpdateSection {
    icon: "󰚰"
    name: "ROG Deck"
    version: page.updater ? page.updater.version : ""
    line: page.updater ? page.updater.line : ""
    available: !!page.updater && page.updater.available
    checking: !!page.updater && page.updater.checking
    busy: !!page.updater && page.updater.busy
    managed: !page.updater || page.updater.managed
    notes: page.updater ? page.updater.notes : []
    showAutoCheck: true
    autoCheck: page.service ? page.service.settings.updates.autoCheck : true
    foreground: page.host.fg
    accent: page.host.accent
    fontFamily: page.host.fontFamily
    onCheckRequested: page.updater.checkNow()
    onApplyRequested: page.updater.apply()
    onAutoCheckToggled: page.service.saveSetting(["updates", "autoCheck"], !page.service.settings.updates.autoCheck)
  }
}
