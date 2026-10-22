import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// Power modes, live readings and the toggles you reach for most.
Column {
  id: tab

  property var deck: null
  readonly property var service: deck ? deck.service : null
  readonly property var status: deck ? deck.status : null
  readonly property var fans: status && status.fans ? status.fans : ({})
  readonly property var watts: status && status.watts ? status.watts : ({})
  readonly property var battery: status ? status.battery : null
  readonly property var anime: status ? status.anime : null

  spacing: Style.space(12)

  // ---------- Power mode ----------
  SectionHeader {
    icon: "󰓅"
    title: "POWER MODE"
    // What Omarchy puts back when the charger changes.
    detail: {
      var saved = tab.status && tab.status.profile ? tab.status.profile.saved : null
      if (!saved || (!saved.ac && !saved.battery)) return ""
      return ("AC " + Model.profileInfo(saved.ac).label + " · BAT " + Model.profileInfo(saved.battery).label).toUpperCase()
    }
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    visible: tab.deck.profiles.length > 0
  }

  Column {
    width: parent.width
    spacing: Style.space(2)
    visible: tab.deck.profiles.length > 0

    Repeater {
      model: tab.deck.profiles

      OptionRow {
        required property var modelData
        required property int index
        width: parent.width
        icon: modelData.icon
        title: modelData.label
        subtitle: modelData.hint
        current: tab.deck.activeProfile === modelData.key
        keyboardCursor: tab.deck.cursorActive && tab.deck.profileCursor === index
        foreground: tab.deck.fg
        fontFamily: tab.deck.fontFamily
        onClicked: if (tab.service) tab.service.setProfile(modelData.key)
      }
    }
  }

  PanelSeparator { foreground: tab.deck.fg }

  // ---------- Readings ----------
  SectionHeader {
    icon: "󰔏"
    title: "LIVE"
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
  }

  Grid {
    id: tiles
    width: parent.width
    columns: 3
    columnSpacing: Style.space(8)
    rowSpacing: Style.space(8)

    readonly property real tileWidth: (width - columnSpacing * (columns - 1)) / columns

    StatTile {
      width: tiles.tileWidth
      icon: "󰈐"
      caption: "CPU FAN"
      value: Model.rpm(tab.fans.cpu) + (tab.fans.cpu ? " rpm" : "")
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
    }
    StatTile {
      width: tiles.tileWidth
      icon: "󰈐"
      caption: "GPU FAN"
      value: Model.rpm(tab.fans.gpu) + (tab.fans.gpu ? " rpm" : "")
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
    }
    StatTile {
      width: tiles.tileWidth
      icon: "󰻠"
      caption: "PACKAGE"
      value: tab.watts.igpu !== null && tab.watts.igpu !== undefined ? Model.watts(tab.watts.igpu) : "—"
      note: "CPU and iGPU"
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
    }
    StatTile {
      width: tiles.tileWidth
      icon: tab.status && tab.status.ac ? "󰂄" : "󰁹"
      caption: "BATTERY"
      value: tab.battery && tab.battery.percent !== null ? tab.battery.percent + "%" : "—"
      note: {
        if (!tab.battery) return ""
        var parts = []
        if (tab.battery.watts) parts.push((tab.status.ac ? "+" : "−") + Model.watts(tab.battery.watts))
        if (tab.battery.limit && tab.battery.limit < 100) parts.push("limit " + tab.battery.limit + "%")
        return parts.join(" · ")
      }
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
    }
    StatTile {
      width: tiles.tileWidth
      icon: "󰢮"
      caption: "DGPU"
      value: tab.status ? Model.dgpuLabel(tab.status.dgpu).replace(/^./, function(c) { return c.toUpperCase() }) : "—"
      note: tab.watts.dgpu ? Model.watts(tab.watts.dgpu) : (tab.status && tab.status.dgpu === "suspended" ? "about 0 W" : "")
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
    }
    StatTile {
      width: tiles.tileWidth
      icon: "󰍹"
      caption: "SCREEN"
      value: tab.status && tab.status.display ? tab.status.display.refresh + " Hz" : "—"
      note: tab.service && tab.service.settings.refresh === "auto" ? "Auto" : ""
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
    }
  }

  PanelSeparator { foreground: tab.deck.fg }

  // ---------- Quick controls ----------
  SectionHeader {
    icon: "󰌌"
    title: "KEYBOARD LIGHT"
    detail: {
      var level = tab.service && tab.status && tab.status.keyboard ? tab.service.pick("kbd.brightness", tab.status.keyboard.brightness) : null
      return level === null || level === undefined ? "" : Model.KBD_LEVELS[Math.max(0, Math.min(3, level))].label.toUpperCase()
    }
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    visible: !!(tab.status && tab.status.keyboard && tab.status.keyboard.brightness !== null)
  }

  SliderField {
    width: parent.width
    visible: !!(tab.status && tab.status.keyboard && tab.status.keyboard.brightness !== null)
    showValue: false
    from: 0
    to: 3
    step: 1
    tickCount: 4
    value: tab.service && tab.status ? tab.service.pick("kbd.brightness", tab.status.keyboard.brightness) || 0 : 0
    bar: tab.deck.bar
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onCommitted: function(v) { tab.service.setKbdBrightness(Math.round(v)) }
  }

  SwitchRow {
    width: parent.width
    visible: !!tab.anime
    icon: "󱗼"
    label: "AniMe Matrix"
    hint: tab.anime ? (Model.animeContent(tab.anime) === "logo" ? "Showing the ROG logo" : "Showing the banner") : ""
    checked: tab.service && tab.anime ? !!tab.service.pick("anime.enabled", tab.anime.enabled) : false
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onToggled: tab.service.setAnimeEnabled(!checked)
  }

  SwitchRow {
    width: parent.width
    visible: !!(tab.status && tab.status.fnlock && tab.status.fnlock.available)
    icon: "󰌾"
    label: "FN-lock"
    hint: "Action row does its printed media actions"
    checked: tab.service && tab.status ? !!tab.service.pick("fnlock", tab.status.fnlock.on) : false
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onToggled: tab.service.setFnlock(!checked)
  }
}
