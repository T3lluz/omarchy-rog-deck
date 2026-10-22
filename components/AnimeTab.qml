import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// AniMe Matrix: what it shows, brightness, the firmware animations for
// boot, sleep and shutdown, and when it turns itself off.
Column {
  id: tab

  property var deck: null
  readonly property var service: deck ? deck.service : null
  readonly property var status: deck ? deck.status : null
  readonly property var anime: status && status.anime ? status.anime : ({ builtins: {} })
  readonly property var saved: service ? service.settings.anime : Model.defaultSettings().anime
  readonly property bool displayOn: service ? !!service.pick("anime.enabled", anime.enabled) : false
  readonly property string content: service
    ? service.pick("anime.content", Model.animeContent(saved.content, anime)) : "banner"
  readonly property bool offWhenSuspended: service ? !!service.pick("anime.option.suspended", anime.offWhenSuspended) : false

  spacing: Style.space(12)

  SwitchRow {
    width: parent.width
    label: "Display"
    checked: tab.displayOn
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onToggled: tab.service.setAnimeEnabled(!tab.displayOn)
  }

  Column {
    width: parent.width
    spacing: Style.space(12)
    opacity: tab.displayOn ? 1 : 0.5

    SectionLabel { text: "SHOW"; foreground: tab.deck.fg; fontFamily: tab.deck.fontFamily }

    Seg {
      width: parent.width
      options: Model.ANIME_CONTENT
      value: tab.content
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
      onPicked: function(v) {
        if (v === "custom" && !tab.saved.customPath) tab.service.pickAnimeImage()
        else tab.service.setAnimeContent(v)
      }
    }

    Text {
      width: parent.width
      visible: tab.content === "logo"
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      text: "The firmware sets how often the logo glitches. Static shows the same eye, still."
      color: tab.deck.fg
      opacity: 0.55
      font.family: tab.deck.fontFamily
      font.pixelSize: Style.font.caption
    }

    Item {
      width: parent.width
      height: chooseButton.implicitHeight
      visible: tab.content === "custom"

      Text {
        anchors.left: parent.left
        anchors.right: chooseButton.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        elide: Text.ElideMiddle
        text: tab.saved.customPath ? tab.saved.customPath.replace(/^.*\//, "") : "No image picked"
        color: tab.deck.fg
        font.family: tab.deck.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Button {
        id: chooseButton
        anchors.right: parent.right
        text: "Choose…"
        fontSize: Style.font.bodySmall
        foreground: tab.deck.fg
        fontFamily: tab.deck.fontFamily
        bordered: true
        onClicked: tab.service.pickAnimeImage()
      }
    }

    SliderField {
      width: parent.width
      label: "Brightness"
      from: 1
      to: 3
      step: 1
      tickCount: 3
      format: function(v) { return ["Low", "Med", "High"][Math.max(0, Math.min(2, Math.round(v) - 1))] }
      value: tab.service ? Math.max(1, tab.service.pick("anime.brightness", tab.anime.brightness) || 1) : 1
      bar: tab.deck.bar
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
      onCommitted: function(v) { tab.service.setAnimeBrightness(Math.round(v)) }
    }

    // ---------- Placement of the still logo or your image ----------
    Column {
      width: parent.width
      spacing: Style.space(10)
      visible: tab.content === "static" || (tab.content === "custom" && tab.saved.customPath !== "")

      readonly property var place: tab.saved.placement && tab.saved.placement[tab.content]
        ? tab.saved.placement[tab.content] : Model.animePlacementDefaults(tab.content)

      Item {
        width: parent.width
        height: resetPlacement.implicitHeight

        SectionLabel {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "PLACEMENT"
          foreground: tab.deck.fg
          fontFamily: tab.deck.fontFamily
        }

        Button {
          id: resetPlacement
          anchors.right: parent.right
          text: "Reset"
          tooltipText: tab.content === "static" ? "Back to where the firmware logo sits" : "Centred, fitted, unrotated"
          fontSize: Style.font.caption
          foreground: tab.deck.fg
          fontFamily: tab.deck.fontFamily
          bordered: true
          onClicked: tab.service.resetAnimePlacement()
        }
      }

      SliderField {
        width: parent.width
        label: "Size"
        from: 0.3
        to: 3
        step: 0.05
        format: function(v) { return Number(v).toFixed(2) + "×" }
        value: parent.place.scale
        bar: tab.deck.bar
        foreground: tab.deck.fg
        fontFamily: tab.deck.fontFamily
        onCommitted: function(v) { tab.service.setAnimePlacement("scale", Math.round(v * 100) / 100) }
      }

      SliderField {
        width: parent.width
        label: "Left / right"
        from: -14
        to: 14
        step: 0.2
        format: function(v) { return (v > 0 ? "+" : "") + Number(v).toFixed(1) }
        value: parent.place.x
        bar: tab.deck.bar
        foreground: tab.deck.fg
        fontFamily: tab.deck.fontFamily
        onCommitted: function(v) { tab.service.setAnimePlacement("x", Math.round(v * 10) / 10) }
      }

      SliderField {
        width: parent.width
        label: "Up / down"
        from: -9
        to: 9
        step: 0.2
        format: function(v) { return (v > 0 ? "+" : "") + Number(v).toFixed(1) }
        value: parent.place.y
        bar: tab.deck.bar
        foreground: tab.deck.fg
        fontFamily: tab.deck.fontFamily
        onCommitted: function(v) { tab.service.setAnimePlacement("y", Math.round(v * 10) / 10) }
      }

      SliderField {
        width: parent.width
        label: "Rotate (degrees)"
        from: -180
        to: 180
        step: 1
        showField: true
        value: parent.place.angle
        bar: tab.deck.bar
        foreground: tab.deck.fg
        fontFamily: tab.deck.fontFamily
        onCommitted: function(v) { tab.service.setAnimePlacement("angle", Math.round(v)) }
      }

      SliderField {
        width: parent.width
        label: "Image brightness (%)"
        from: 5
        to: 100
        step: 5
        showField: true
        value: parent.place.bright
        bar: tab.deck.bar
        foreground: tab.deck.fg
        fontFamily: tab.deck.fontFamily
        onCommitted: function(v) { tab.service.setAnimePlacement("bright", Math.round(v)) }
      }
    }

    SectionLabel { text: "ANIMATIONS"; foreground: tab.deck.fg; fontFamily: tab.deck.fontFamily }

    Text {
      width: parent.width
      visible: tab.content === "static" || tab.content === "custom"
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      text: "These play only with Banner or Logo: an image switches the firmware animations off."
      color: tab.deck.fg
      opacity: 0.55
      font.family: tab.deck.fontFamily
      font.pixelSize: Style.font.caption
    }

    Repeater {
      model: [{ slot: "boot", label: "Boot" }, { slot: "sleep", label: "Sleep" }, { slot: "shutdown", label: "Shutdown" }]

      Item {
        required property var modelData
        width: parent.width
        height: slotSeg.implicitHeight

        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: parent.modelData.label
          color: tab.deck.fg
          opacity: 0.6
          font.family: tab.deck.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Seg {
          id: slotSeg
          anchors.right: parent.right
          width: parent.width * 0.68
          options: Model.ANIME_BUILTIN_CHOICES[parent.modelData.slot]
          value: tab.service ? tab.service.pick("anime." + parent.modelData.slot, tab.anime.builtins[parent.modelData.slot]) : ""
          foreground: tab.deck.fg
          fontFamily: tab.deck.fontFamily
          onPicked: function(v) { tab.service.setAnimeBuiltin(parent.modelData.slot, v) }
        }
      }
    }

    PanelSeparator { foreground: tab.deck.fg }

    SectionLabel { text: "TURN OFF"; foreground: tab.deck.fg; fontFamily: tab.deck.fontFamily }

    SwitchRow {
      width: parent.width
      label: "On battery"
      checked: tab.service ? !!tab.service.pick("anime.option.unplugged", tab.anime.offWhenUnplugged) : false
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
      onToggled: tab.service.setAnimeOption("unplugged", !checked)
    }

    SwitchRow {
      width: parent.width
      label: "When the laptop sleeps"
      hint: tab.offWhenSuspended ? "Turn this off to see the sleep animation" : "The sleep animation plays while suspended"
      checked: tab.offWhenSuspended
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
      onToggled: tab.service.setAnimeOption("suspended", !checked)
    }

    SwitchRow {
      width: parent.width
      label: "When the lid is closed"
      checked: tab.service ? !!tab.service.pick("anime.option.lid", tab.anime.offWhenLidClosed) : false
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
      onToggled: tab.service.setAnimeOption("lid", !checked)
    }
  }
}
