import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// Keyboard backlight: brightness, effect, colour, auto-off, power states.
Column {
  id: tab

  property var deck: null
  readonly property var service: deck ? deck.service : null
  readonly property var status: deck ? deck.status : null
  readonly property var kb: status && status.keyboard ? status.keyboard : ({})
  readonly property var settings: service ? service.settings : Model.defaultSettings()
  readonly property var light: settings.kbdLight
  readonly property var idle: settings.kbdIdle
  readonly property var effects: Model.auraEffects(kb.modes, light.rgb)
  // Until the user picks one here, show what the keyboard is running.
  readonly property string effectKey: {
    if (light.managed) return light.effect
    var running = Model.auraEffectByMode(service ? service.pick("kbd.mode", kb.mode) : kb.mode)
    return running ? running.key : "static"
  }
  readonly property var effect: Model.auraEffect(effectKey)
  readonly property var power: kb.power || ({ boot: true, awake: true, sleep: true, shutdown: true })

  spacing: Style.space(12)

  SliderField {
    width: parent.width
    label: "Brightness"
    from: 0
    to: 3
    step: 1
    tickCount: 4
    format: function(v) { return Model.KBD_LEVELS[Math.max(0, Math.min(3, Math.round(v)))].label }
    value: tab.service ? tab.service.pick("kbd.brightness", tab.kb.brightness) || 0 : 0
    bar: tab.deck.bar
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onCommitted: function(v) { tab.service.setKbdBrightness(Math.round(v)) }
  }

  SectionLabel { text: "EFFECT"; foreground: tab.deck.fg; fontFamily: tab.deck.fontFamily; visible: tab.effects.length > 1 }

  Seg {
    width: parent.width
    visible: tab.effects.length > 1
    options: tab.effects.map(function(e) { return { value: e.key, label: e.label } })
    value: tab.effectKey
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onPicked: function(v) { tab.service.setLighting("effect", v) }
  }

  Seg {
    width: parent.width
    visible: !!(tab.effect && tab.effect.speed)
    options: [{ value: "low", label: "Slow" }, { value: "med", label: "Medium" }, { value: "high", label: "Fast" }]
    value: tab.light.speed
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onPicked: function(v) { tab.service.setLighting("speed", v) }
  }

  Column {
    width: parent.width
    spacing: Style.space(10)
    visible: tab.light.rgb && !!(tab.effect && tab.effect.colour)

    SwitchRow {
      width: parent.width
      label: "Follow the Omarchy theme"
      hint: "Uses the theme's keyboard colour and changes with it"
      checked: tab.light.followTheme
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
      onToggled: tab.service.setLighting("followTheme", !tab.light.followTheme)
    }

    Row {
      id: swatches
      width: parent.width
      spacing: Style.space(8)
      visible: !tab.light.followTheme

      readonly property real size: (width - spacing * (Model.SWATCHES.length - 1)) / Model.SWATCHES.length

      Repeater {
        model: Model.SWATCHES

        Rectangle {
          required property string modelData
          width: swatches.size
          height: Style.space(22)
          radius: Style.cornerRadius > 0 ? height / 2 : 0
          color: "#" + modelData
          border.width: tab.light.colour === modelData ? Math.max(2, Style.space(2)) : 0
          border.color: tab.deck.fg

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tab.service.setLighting("colour", parent.modelData)
          }
        }
      }
    }
  }

  PanelSeparator { foreground: tab.deck.fg }

  SectionLabel { text: "AUTO-OFF"; foreground: tab.deck.fg; fontFamily: tab.deck.fontFamily }

  SwitchRow {
    width: parent.width
    label: "Turn off when idle"
    hint: "Goes dark after no typing or touchpad, back on the next key press"
    checked: tab.idle.enabled
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onToggled: tab.service.setKbdIdle("enabled", !tab.idle.enabled)
  }

  SliderField {
    id: idleField
    width: parent.width
    interactive: tab.idle.enabled
    label: "After " + Model.formatSeconds(idleField.shown) + " (seconds)"
    from: 5
    to: 600
    step: 5
    showField: true
    value: tab.idle.timeout
    bar: tab.deck.bar
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onCommitted: function(v) { tab.service.setKbdIdle("timeout", Math.max(5, Math.round(v))) }
  }

  SwitchRow {
    width: parent.width
    interactive: tab.idle.enabled
    label: "Stay on while plugged in"
    checked: tab.idle.keepOnAc
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onToggled: tab.service.setKbdIdle("keepOnAc", !tab.idle.keepOnAc)
  }

  SwitchRow {
    width: parent.width
    interactive: tab.idle.enabled
    label: "Dim instead of turning off"
    checked: tab.idle.dimOnly
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onToggled: tab.service.setKbdIdle("dimOnly", !tab.idle.dimOnly)
  }

  PanelSeparator { foreground: tab.deck.fg; visible: !!tab.kb.power }

  SectionLabel { text: "LIGHT UP DURING"; foreground: tab.deck.fg; fontFamily: tab.deck.fontFamily; visible: !!tab.kb.power }

  Row {
    id: powerRow
    width: parent.width
    spacing: Style.space(6)
    visible: !!tab.kb.power

    readonly property var slots: [
      { key: "boot", label: "Boot" }, { key: "awake", label: "Awake" },
      { key: "sleep", label: "Sleep" }, { key: "shutdown", label: "Shutdown" }
    ]
    readonly property real cellWidth: (width - spacing * (slots.length - 1)) / slots.length

    Repeater {
      model: powerRow.slots

      Button {
        required property var modelData
        readonly property bool on: tab.service ? tab.service.pick("kbd.power." + modelData.key, tab.power[modelData.key]) : false
        width: powerRow.cellWidth
        text: modelData.label
        iconText: on ? "󰄬" : ""
        iconSize: Style.font.body
        fontSize: Style.font.bodySmall
        foreground: tab.deck.fg
        fontFamily: tab.deck.fontFamily
        bordered: true
        active: on
        onClicked: tab.service.setLedPower(modelData.key, !on)
      }
    }
  }

  SwitchRow {
    width: parent.width
    label: "Keyboard has RGB colours"
    hint: "Leave off for a white-only backlight: keeps it on Static"
    checked: tab.light.rgb
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onToggled: tab.service.setLighting("rgb", !tab.light.rgb)
  }
}
