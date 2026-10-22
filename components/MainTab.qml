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

  spacing: Style.space(14)

  Column {
    width: parent.width
    spacing: Style.space(8)
    visible: tab.deck.profiles.length > 0

    SectionLabel { text: "POWER MODE"; foreground: tab.deck.fg; fontFamily: tab.deck.fontFamily }

    Row {
      id: profileRow
      width: parent.width
      spacing: Style.space(6)

      readonly property real cellWidth: tab.deck.profiles.length > 0
        ? (width - spacing * (tab.deck.profiles.length - 1)) / tab.deck.profiles.length : 0

      Repeater {
        model: tab.deck.profiles

        Button {
          required property var modelData
          required property int index
          width: profileRow.cellWidth
          iconText: modelData.icon
          iconSize: Style.font.title
          text: modelData.label
          tooltipText: modelData.hint
          fontSize: Style.font.bodySmall
          foreground: tab.deck.fg
          fontFamily: tab.deck.fontFamily
          verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
          bordered: true
          active: tab.deck.activeProfile === modelData.key
          hasCursor: tab.deck.cursorActive && tab.deck.profileCursor === index
          onClicked: if (tab.service) tab.service.setProfile(modelData.key)
          onHovered: function(h) {
            if (!h) return
            tab.deck.cursorActive = true
            tab.deck.profileCursor = index
          }
        }
      }
    }
  }

  Grid {
    width: parent.width
    columns: 2
    columnSpacing: Style.space(20)
    rowSpacing: Style.spacing.labelGap

    readonly property real cellWidth: (width - columnSpacing) / 2

    InfoPair {
      width: parent.cellWidth
      label: "CPU fan"
      value: tab.status && tab.status.fans ? Model.rpm(tab.status.fans.cpu) + " rpm" : "—"
    }
    InfoPair {
      width: parent.cellWidth
      label: "GPU fan"
      value: tab.status && tab.status.fans ? Model.rpm(tab.status.fans.gpu) + " rpm" : "—"
    }
    InfoPair {
      width: parent.cellWidth
      label: "Battery"
      value: tab.status ? (Model.batteryLine(tab.status.battery, tab.status.ac) || "—") : "—"
    }
    InfoPair {
      width: parent.cellWidth
      label: "Dedicated GPU"
      value: {
        if (!tab.status) return "—"
        var text = Model.dgpuLabel(tab.status.dgpu)
        var w = tab.status.watts ? tab.status.watts.dgpu : null
        return w ? text + " · " + Model.watts(w) : text
      }
    }
  }

  PanelSeparator { foreground: tab.deck.fg }

  Column {
    width: parent.width
    spacing: Style.space(8)
    visible: !!(tab.status && tab.status.keyboard && tab.status.keyboard.brightness !== null)

    SliderField {
      width: parent.width
      label: "Keyboard light"
      from: 0
      to: 3
      step: 1
      tickCount: 4
      format: function(v) { return Model.KBD_LEVELS[Math.max(0, Math.min(3, Math.round(v)))].label }
      value: tab.service && tab.status ? tab.service.pick("kbd.brightness", tab.status.keyboard.brightness) || 0 : 0
      bar: tab.deck.bar
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
      onCommitted: function(v) { tab.service.setKbdBrightness(Math.round(v)) }
    }
  }

  SwitchRow {
    width: parent.width
    visible: !!(tab.status && tab.status.anime)
    label: "AniMe Matrix"
    checked: tab.service && tab.status && tab.status.anime ? !!tab.service.pick("anime.enabled", tab.status.anime.enabled) : false
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onToggled: tab.service.setAnimeEnabled(!checked)
  }

  SwitchRow {
    width: parent.width
    visible: !!(tab.status && tab.status.fnlock && tab.status.fnlock.available)
    label: "FN-lock"
    hint: "Action row does its printed media actions"
    checked: tab.service && tab.status ? !!tab.service.pick("fnlock", tab.status.fnlock.on) : false
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onToggled: tab.service.setFnlock(!checked)
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""
    spacing: Style.space(8)

    Text {
      id: pairLabel
      textFormat: Text.PlainText
      text: parent.label
      color: tab.deck.fg
      opacity: 0.6
      font.family: tab.deck.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Item { width: Math.max(0, parent.width - pairLabel.implicitWidth - pairValue.implicitWidth - parent.spacing * 2); height: 1 }
    Text {
      id: pairValue
      textFormat: Text.PlainText
      text: parent.value
      color: tab.deck.fg
      font.family: tab.deck.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }
}
