import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// AniMe Matrix: the firmware's banner or ROG logo, brightness, the startup,
// sleep and shutdown animations, and when the display turns itself off.
Column {
  id: tab

  property var deck: null
  readonly property var service: deck ? deck.service : null
  readonly property var status: deck ? deck.status : null
  readonly property var anime: status && status.anime ? status.anime : ({ builtins: {} })
  readonly property var builtins: anime.builtins || ({})
  readonly property bool displayOn: service ? !!service.pick("anime.enabled", anime.enabled) : false
  readonly property string awake: service ? service.pick("anime.awake", builtins.awake) || "" : ""
  readonly property int brightness: service ? Math.max(1, service.pick("anime.brightness", anime.brightness) || 1) : 1
  readonly property bool offWhenSuspended: service ? !!service.pick("anime.option.suspended", anime.offWhenSuspended) : false

  spacing: Style.space(12)

  // ---------- Display ----------
  SectionHeader {
    icon: "󱗼"
    title: "ANIME MATRIX"
    showSwitch: true
    checked: tab.displayOn
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onToggled: tab.service.setAnimeEnabled(!tab.displayOn)
  }

  Column {
    width: parent.width
    spacing: Style.space(12)
    opacity: tab.displayOn ? 1 : 0.5

    Column {
      width: parent.width
      spacing: Style.space(2)

      Repeater {
        model: Model.ANIME_CONTENT

        OptionRow {
          required property var modelData
          width: parent.width
          icon: modelData.icon
          title: modelData.label
          subtitle: modelData.hint
          current: tab.awake === modelData.builtin
          foreground: tab.deck.fg
          fontFamily: tab.deck.fontFamily
          onClicked: tab.service.setAnimeContent(modelData.value)
        }
      }
    }

    PanelSeparator { foreground: tab.deck.fg }

    // ---------- Brightness ----------
    SectionHeader {
      icon: "󰃟"
      title: "BRIGHTNESS"
      detail: ["LOW", "MED", "HIGH"][Math.max(0, Math.min(2, tab.brightness - 1))]
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
    }

    SliderField {
      width: parent.width
      showValue: false
      from: 1
      to: 3
      step: 1
      tickCount: 3
      value: tab.brightness
      bar: tab.deck.bar
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
      onCommitted: function(v) { tab.service.setAnimeBrightness(Math.round(v)) }
    }

    PanelSeparator { foreground: tab.deck.fg }

    // ---------- Startup / sleep / shutdown ----------
    SectionHeader {
      icon: "󰐊"
      title: "ANIMATIONS"
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
    }

    Repeater {
      model: Model.ANIME_SLOTS

      Item {
        required property var modelData
        width: parent.width
        height: slotSeg.implicitHeight

        Text {
          id: slotIcon
          anchors.left: parent.left
          anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(22)
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.PlainText
          text: parent.modelData.icon
          color: tab.deck.fg
          font.family: tab.deck.fontFamily
          font.pixelSize: Style.font.title
        }

        Text {
          anchors.left: slotIcon.right
          anchors.leftMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: parent.modelData.label
          color: tab.deck.fg
          font.family: tab.deck.fontFamily
          font.pixelSize: Style.font.body
        }

        Seg {
          id: slotSeg
          anchors.right: parent.right
          width: parent.width * 0.6
          options: Model.ANIME_BUILTIN_CHOICES[parent.modelData.slot]
          value: tab.service ? tab.service.pick("anime." + parent.modelData.slot, tab.builtins[parent.modelData.slot]) : ""
          foreground: tab.deck.fg
          fontFamily: tab.deck.fontFamily
          onPicked: function(v) { tab.service.setAnimeBuiltin(parent.modelData.slot, v) }
        }
      }
    }

    PanelSeparator { foreground: tab.deck.fg }

    // ---------- Turn off ----------
    SectionHeader {
      icon: "󰐦"
      title: "TURN OFF"
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
    }

    SwitchRow {
      width: parent.width
      icon: "󰁹"
      label: "On battery"
      checked: tab.service ? !!tab.service.pick("anime.option.unplugged", tab.anime.offWhenUnplugged) : false
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
      onToggled: tab.service.setAnimeOption("unplugged", !checked)
    }

    SwitchRow {
      width: parent.width
      icon: "󰒲"
      label: "When the laptop sleeps"
      hint: tab.offWhenSuspended ? "Turn off to see the sleep animation" : "The sleep animation plays while suspended"
      checked: tab.offWhenSuspended
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
      onToggled: tab.service.setAnimeOption("suspended", !checked)
    }

    SwitchRow {
      width: parent.width
      icon: "󰌢"
      label: "When the lid is closed"
      checked: tab.service ? !!tab.service.pick("anime.option.lid", tab.anime.offWhenLidClosed) : false
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
      onToggled: tab.service.setAnimeOption("lid", !checked)
    }
  }
}
